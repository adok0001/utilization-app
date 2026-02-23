# ============================================================
# physician_detail_module.R — Individual physician analytics
# ============================================================

# ── UI ────────────────────────────────────────────────────────
physicianDetailUI <- function(id) {
  ns <- NS(id)
  tagList(
    h2("Physician View", class = "page-title"),
    fluidRow(
      column(3,
        card(
          card_header("Filters"),
          card_body(
            selectInput(ns("physician_sel"), "Physician",
                        choices = NULL, selected = NULL),
            selectInput(ns("year_sel"), "Year",
                        choices = NULL, selected = NULL),
            actionButton(ns("apply_btn"), "Apply", class = "btn-primary w-100")
          )
        )
      ),
      column(9,
        uiOutput(ns("physician_kpi_row")),
        fluidRow(
          column(6,
            card(card_header("Monthly Hours"),
                 card_body(plotlyOutput(ns("hours_trend"), height = "240px")))
          ),
          column(6,
            card(card_header("Monthly Compensation"),
                 card_body(plotlyOutput(ns("comp_trend"), height = "240px")))
          )
        ),
        fluidRow(
          column(6,
            card(card_header("Hourly Rate Trend"),
                 card_body(plotlyOutput(ns("rate_trend"), height = "240px")))
          ),
          column(6,
            card(card_header("vs. Peer Average (Hours)"),
                 card_body(plotlyOutput(ns("peer_compare"), height = "240px")))
          )
        ),
        card(
          card_header("Shift Detail"),
          card_body(DTOutput(ns("shift_table")))
        )
      )
    )
  )
}

# ── Server ────────────────────────────────────────────────────
physicianDetailServer <- function(id, r) {
  moduleServer(id, function(input, output, session) {

    phys_list <- reactive_physician_list(r)
    monthly   <- reactive_monthly_summary(r)

    # ── Populate selectors ──
    observe({
      pl <- phys_list()
      updateSelectInput(session, "physician_sel",
                        choices = setNames(pl$physician_id, pl$physician_name))
    })

    observe({
      m <- monthly()
      yrs <- if (nrow(m) > 0) sort(unique(m$year), decreasing = TRUE) else year(Sys.Date())
      updateSelectInput(session, "year_sel", choices = yrs, selected = yrs[1])
    })

    # ── Filtered data ──
    selected_data <- eventReactive(input$apply_btn, {
      m <- monthly()
      req(nrow(m) > 0, input$physician_sel)
      m[physician_id == input$physician_sel & year == as.integer(input$year_sel)]
    }, ignoreNULL = FALSE)

    # ── KPI row ──
    output$physician_kpi_row <- renderUI({
      d <- selected_data()
      req(nrow(d) > 0)
      fluidRow(
        column(3, kpi_card("Total Hours",       fmt_hours(sum(d$total_hours, na.rm = TRUE)),        icon("clock"),        "info")),
        column(3, kpi_card("Total Compensation", fmt_currency(sum(d$total_compensation, na.rm = TRUE)), icon("dollar-sign"), "success")),
        column(3, kpi_card("Avg Hourly Rate",   fmt_currency(mean(d$avg_hourly_rate, na.rm = TRUE)), icon("hand-holding-dollar"), "primary")),
        column(3, kpi_card("FTE %",             fmt_pct(mean(d$fte_pct, na.rm = TRUE)),              icon("percent"),     "secondary"))
      )
    })

    # ── Plots ──
    output$hours_trend <- renderPlotly({
      d <- selected_data(); req(nrow(d) > 0)
      plot_ly(d, x = ~month, y = ~total_hours, type = "bar", marker = list(color = COL_PRIMARY)) |>
        layout(xaxis = list(title = "Month"), yaxis = list(title = "Hours"), margin = list(t=5))
    })

    output$comp_trend <- renderPlotly({
      d <- selected_data(); req(nrow(d) > 0)
      plot_ly(d, x = ~month, y = ~total_compensation, type = "scatter", mode = "lines+markers",
              line = list(color = COL_SUCCESS)) |>
        layout(xaxis = list(title = "Month"), yaxis = list(title = "USD"), margin = list(t=5))
    })

    output$rate_trend <- renderPlotly({
      d <- selected_data(); req(nrow(d) > 0)
      plot_ly(d, x = ~month, y = ~avg_hourly_rate, type = "scatter", mode = "lines+markers",
              line = list(color = COL_WARNING)) |>
        layout(xaxis = list(title = "Month"), yaxis = list(title = "$/hr"), margin = list(t=5))
    })

    output$peer_compare <- renderPlotly({
      d <- selected_data(); req(nrow(d) > 0, "peer_avg_hours" %in% names(d))
      plot_ly(d, x = ~month) |>
        add_bars(y = ~total_hours, name = "This Physician", marker = list(color = COL_PRIMARY)) |>
        add_lines(y = ~peer_avg_hours, name = "Peer Average",
                  line = list(color = COL_DANGER, dash = "dash")) |>
        layout(xaxis = list(title = "Month"), yaxis = list(title = "Hours"), margin = list(t=5))
    })

    # ── Shift detail table ──
    output$shift_table <- renderDT({
      req(input$physician_sel)
      d <- get_raw_hours(r$db_con,
                          physician_id = input$physician_sel,
                          year = as.integer(input$year_sel))
      datatable(d, rownames = FALSE,
                options = list(pageLength = 15, scrollX = TRUE))
    })
  })
}
