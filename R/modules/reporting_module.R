# ============================================================
# reporting_module.R — Report generation and export
# ============================================================

# ── UI ────────────────────────────────────────────────────────
reportingUI <- function(id) {
  ns <- NS(id)
  tagList(
    h2("Reports & Export", class = "page-title"),
    fluidRow(
      # ── Report builder ──
      column(4,
        card(
          card_header("Generate Report"),
          card_body(
            selectInput(ns("report_type"), "Report Type",
                        choices = c(
                          "Monthly Compensation"  = "monthly_compensation",
                          "Department Summary"    = "department_summary",
                          "Executive Review"      = "executive_review",
                          "Compensation Equity"   = "equity_audit"
                        )),
            selectInput(ns("report_year"),  "Year",  choices = NULL),
            selectInput(ns("report_month"), "Month", choices = NULL),
            selectInput(ns("report_dept"),  "Department (optional)",
                        choices = c("All" = "All"), selected = "All"),
            hr(),
            actionButton(ns("generate_btn"), "Generate Report",
                         class = "btn-primary w-100", icon = icon("file-lines")),
            br(), br(),
            downloadButton(ns("download_pdf"),   "Export PDF",   class = "btn-outline-danger w-100"),
            br(), br(),
            downloadButton(ns("download_excel"), "Export Excel", class = "btn-outline-success w-100"),
            br(), br(),
            downloadButton(ns("download_csv"),   "Export CSV",   class = "btn-outline-secondary w-100")
          )
        )
      ),

      # ── Physician details table  ──
      column(8,
        card(
          card_header("Physician Details Table"),
          card_body(
            fluidRow(
              column(4, selectInput(ns("tbl_year"),  "Year",        choices = NULL)),
              column(4, selectInput(ns("tbl_month"), "Month",       choices = NULL)),
              column(4, selectInput(ns("tbl_dept"),  "Department",  choices = c("All")))
            ),
            DTOutput(ns("physician_table"))
          )
        )
      )
    )
  )
}

# ── Server ────────────────────────────────────────────────────
reportingServer <- function(id, r) {
  moduleServer(id, function(input, output, session) {

    monthly <- reactive_monthly_summary(r)
    dept    <- reactive_dept_summary(r)

    # ── Populate selectors ──
    observe({
      m  <- monthly()
      yrs  <- if (nrow(m) > 0) sort(unique(m$year), decreasing = TRUE) else year(Sys.Date())
      mos  <- 1:12
      depts <- if ("department" %in% names(m) && nrow(m) > 0)
        c("All", sort(unique(m$department))) else "All"

      for (sel in c("report_year", "tbl_year"))
        updateSelectInput(session, sel, choices = yrs, selected = yrs[1])
      for (sel in c("report_month", "tbl_month"))
        updateSelectInput(session, sel, choices = mos, selected = month(Sys.Date()))
      for (sel in c("report_dept", "tbl_dept"))
        updateSelectInput(session, sel, choices = depts)
    })

    # ── Physician detail table ──
    tbl_data <- reactive({
      m <- monthly()
      req(nrow(m) > 0)
      d <- m[year == as.integer(input$tbl_year) & month == as.integer(input$tbl_month)]
      if (!is.null(input$tbl_dept) && input$tbl_dept != "All" && "department" %in% names(d))
        d <- d[department == input$tbl_dept]
      d
    })

    output$physician_table <- renderDT({
      d <- tbl_data()
      display <- intersect(c("physician_name", "department", "total_hours",
                              "total_compensation", "avg_hourly_rate", "fte_pct",
                              "days_worked", "shift_count"), names(d))
      datatable(d[, ..display],
                rownames = FALSE,
                filter   = "top",
                options  = list(pageLength = 20, scrollX = TRUE,
                                serverSide = FALSE)) |>
        formatCurrency(columns = intersect(c("total_compensation","avg_hourly_rate"), display)) |>
        formatRound(columns    = intersect(c("total_hours","fte_pct"), display), digits = 1)
    })

    # ── Report generation (Quarto) ──
    report_params <- reactiveValues(generated = FALSE, file_path = NULL)

    observeEvent(input$generate_btn, {
      showNotification("Generating report…", type = "message", duration = 3)
      params <- list(
        year       = as.integer(input$report_year),
        month      = as.integer(input$report_month),
        department = input$report_dept,
        db_path    = "data/physician_utilization.sqlite"
      )
      qmd_file <- file.path("quarto", paste0(input$report_type, ".qmd"))
      out_file <- tempfile(fileext = ".html")

      tryCatch({
        quarto::quarto_render(
          input    = qmd_file,
          execute_params = params,
          output_file    = out_file
        )
        report_params$file_path  <- out_file
        report_params$generated  <- TRUE
        showNotification("Report ready — use the export buttons to download.", type = "message")
      }, error = function(e) {
        showNotification(paste("Report error:", e$message), type = "error")
      })

      log_action("generate_report", input$report_type, session)
    })

    # ── Downloads ──
    output$download_csv <- downloadHandler(
      filename = function() glue::glue("physician_report_{input$report_year}_{input$report_month}.csv"),
      content  = function(file) {
        data.table::fwrite(tbl_data(), file)
        log_action("export_csv", file, session)
      }
    )

    output$download_excel <- downloadHandler(
      filename = function() glue::glue("physician_report_{input$report_year}_{input$report_month}.xlsx"),
      content  = function(file) {
        writexl::write_xlsx(as.data.frame(tbl_data()), file)
        log_action("export_excel", file, session)
      }
    )

    output$download_pdf <- downloadHandler(
      filename = function() glue::glue("physician_report_{input$report_year}_{input$report_month}.pdf"),
      content  = function(file) {
        req(report_params$generated, report_params$file_path)
        file.copy(report_params$file_path, file)
        log_action("export_pdf", file, session)
      }
    )
  })
}
