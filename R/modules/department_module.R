# ============================================================
# department_module.R — Department-level analytics
# ============================================================

# ── UI ────────────────────────────────────────────────────────
departmentUI <- function(id) {
  ns <- NS(id)
  tagList(
    h2("Department View", class = "page-title"),
    fluidRow(
      column(3,
        card(
          card_header("Filters"),
          card_body(
            selectInput(ns("dept_sel"), "Department", choices = NULL, selected = "All"),
            selectInput(ns("year_sel"), "Year",       choices = NULL, selected = NULL),
            actionButton(ns("apply_btn"), "Apply", class = "btn-primary w-100")
          )
        )
      ),
      column(9,
        uiOutput(ns("dept_kpi_row")),
        fluidRow(
          column(6,
            card(card_header("Monthly Hours by Department"),
                 card_body(plotlyOutput(ns("dept_hours_plot"), height = "260px")))
          ),
          column(6,
            card(card_header("Monthly Compensation by Department"),
                 card_body(plotlyOutput(ns("dept_comp_plot"), height = "260px")))
          )
        ),
        fluidRow(
          column(6,
            card(card_header("FTE Count by Department"),
                 card_body(plotlyOutput(ns("dept_fte_plot"), height = "260px")))
          ),
          column(6,
            card(card_header("Avg Hourly Rate by Department"),
                 card_body(plotlyOutput(ns("dept_rate_plot"), height = "260px")))
          )
        ),
        card(
          card_header("Department Summary Table"),
          card_body(DTOutput(ns("dept_table")))
        )
      )
    )
  )
}

# ── Server ────────────────────────────────────────────────────
departmentServer <- function(id, r) {
  moduleServer(id, function(input, output, session) {

    dept_data <- reactive_dept_summary(r)
    monthly   <- reactive_monthly_summary(r)

    # ── Populate selectors ──
    observe({
      d <- dept_data()
      depts <- if ("department" %in% names(d) && nrow(d) > 0)
        c("All", sort(unique(d$department))) else "All"
      updateSelectInput(session, "dept_sel", choices = depts)
    })

    observe({
      d <- dept_data()
      yrs <- if (nrow(d) > 0) sort(unique(d$year), decreasing = TRUE) else year(Sys.Date())
      updateSelectInput(session, "year_sel", choices = yrs, selected = yrs[1])
    })

    # ── Filtered data ──
    filtered <- eventReactive(input$apply_btn, {
      d <- dept_data()
      req(nrow(d) > 0)
      yr_sel <- as.integer(input$year_sel)
      if (!is.null(input$dept_sel) && input$dept_sel != "All" && "department" %in% names(d))
        d <- d[department == input$dept_sel]
      d[year == yr_sel]
    }, ignoreNULL = FALSE)

    # ── KPI row ──
    output$dept_kpi_row <- renderUI({
      d <- filtered(); req(nrow(d) > 0)
      fluidRow(
        column(3, kpi_card("Total Hours",       fmt_hours(sum(d$total_hours, na.rm = TRUE)),        icon("clock"),        "info")),
        column(3, kpi_card("Total Compensation", fmt_currency(sum(d$total_compensation, na.rm = TRUE)), icon("dollar-sign"), "success")),
        column(3, kpi_card("Total FTE",         fmt_fte(sum(d$total_fte, na.rm = TRUE)),             icon("users"),        "primary")),
        column(3, kpi_card("Physicians",        fmt_number(sum(d$physician_count, na.rm = TRUE), 0), icon("stethoscope"), "secondary"))
      )
    })

    # ── Plots ──
    output$dept_hours_plot <- renderPlotly({
      d <- filtered(); req(nrow(d) > 0, "department" %in% names(d))
      plot_ly(d, x = ~month, y = ~total_hours, color = ~department,
              type = "bar") |>
        layout(barmode = "stack", xaxis = list(title = "Month"),
               yaxis = list(title = "Hours"), margin = list(t = 5))
    })

    output$dept_comp_plot <- renderPlotly({
      d <- filtered(); req(nrow(d) > 0, "department" %in% names(d))
      plot_ly(d, x = ~month, y = ~total_compensation, color = ~department,
              type = "scatter", mode = "lines+markers") |>
        layout(xaxis = list(title = "Month"), yaxis = list(title = "USD"),
               margin = list(t = 5))
    })

    output$dept_fte_plot <- renderPlotly({
      d <- filtered(); req(nrow(d) > 0, "department" %in% names(d))
      fte_sum <- d[, .(total_fte = sum(total_fte, na.rm = TRUE)), by = .(month, department)]
      plot_ly(fte_sum, x = ~month, y = ~total_fte, color = ~department,
              type = "bar") |>
        layout(barmode = "group", xaxis = list(title = "Month"),
               yaxis = list(title = "FTE"), margin = list(t = 5))
    })

    output$dept_rate_plot <- renderPlotly({
      d <- filtered(); req(nrow(d) > 0, "department" %in% names(d))
      rate_avg <- d[, .(avg_rate = mean(avg_hourly_rate, na.rm = TRUE)), by = department]
      plot_ly(rate_avg, x = ~avg_rate, y = ~reorder(department, avg_rate),
              type = "bar", orientation = "h",
              marker = list(color = COL_WARNING)) |>
        layout(xaxis = list(title = "$/hr"), yaxis = list(title = ""),
               margin = list(t = 5, l = 100))
    })

    # ── Summary table ──
    output$dept_table <- renderDT({
      d <- filtered(); req(nrow(d) > 0)
      display_cols <- intersect(c("department", "year", "month", "physician_count",
                                   "total_hours", "total_compensation", "total_fte",
                                   "avg_hourly_rate"), names(d))
      datatable(d[, ..display_cols],
                rownames = FALSE,
                options = list(pageLength = 12, scrollX = TRUE)) |>
        formatCurrency(columns = grep("compensation|rate", display_cols, value = TRUE)) |>
        formatRound(columns   = grep("hours|fte",  display_cols, value = TRUE), digits = 1)
    })
  })
}
