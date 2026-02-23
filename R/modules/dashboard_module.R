# ============================================================
# dashboard_module.R — Main KPI dashboard
# ============================================================

# ── UI ────────────────────────────────────────────────────────
dashboardUI <- function(id) {
  ns <- NS(id)
  tagList(
    h2("Dashboard", class = "page-title"),

    # ── KPI header row ──
    uiOutput(ns("kpi_row")),

    # ── Alert banner ──
    uiOutput(ns("alert_banner")),

    fluidRow(
      # Hours trend
      column(6,
        card(
          card_header("Monthly Hours (All Physicians)"),
          card_body(plotlyOutput(ns("monthly_hours_plot"), height = "280px"))
        )
      ),
      # Compensation trend
      column(6,
        card(
          card_header("Monthly Compensation Cost"),
          card_body(plotlyOutput(ns("monthly_comp_plot"), height = "280px"))
        )
      )
    ),

    fluidRow(
      # Top physicians by hours
      column(6,
        card(
          card_header("Top 10 Physicians by Hours (Current Year)"),
          card_body(plotlyOutput(ns("top_physicians_plot"), height = "280px"))
        )
      ),
      # Department breakdown
      column(6,
        card(
          card_header("Compensation by Department"),
          card_body(plotlyOutput(ns("dept_comp_plot"), height = "280px"))
        )
      )
    ),

    # Recent uploads
    card(
      card_header("Recent Upload Activity"),
      card_body(DTOutput(ns("recent_uploads")))
    )
  )
}

# ── Server ────────────────────────────────────────────────────
dashboardServer <- function(id, r) {
  moduleServer(id, function(input, output, session) {

    kpis       <- reactive_kpis(r)
    monthly    <- reactive_monthly_summary(r)
    dept       <- reactive_dept_summary(r)
    hist       <- reactive_upload_history(r)

    # ── KPI Cards ──
    output$kpi_row <- renderUI({
      k <- kpis()
      fluidRow(
        column(3, kpi_card("Physicians Tracked", fmt_number(k$total_physicians %||% 0, 0), icon("user-doctor"), "primary")),
        column(3, kpi_card("Total Hours", fmt_hours(k$total_hours %||% 0), icon("clock"), "info")),
        column(3, kpi_card("Total Compensation", fmt_currency(k$total_compensation %||% 0), icon("dollar-sign"), "success")),
        column(3, kpi_card("Last Upload", if (is.na(k$last_upload)) "None" else k$last_upload, icon("upload"), "secondary"))
      )
    })

    # ── Alert banner ──
    output$alert_banner <- renderUI({
      h <- hist()
      failed <- h[h$status != "success", ]
      if (nrow(failed) == 0) return(NULL)
      div(class = "alert alert-warning",
        icon("triangle-exclamation"), " ",
        glue::glue("{nrow(failed)} recent upload(s) had issues. Check the Upload tab for details.")
      )
    })

    # ── Monthly hours trend ──
    output$monthly_hours_plot <- renderPlotly({
      m <- monthly()
      req(nrow(m) > 0)
      trend <- m[, .(total_hours = sum(total_hours, na.rm = TRUE)),
                   by = .(year, month)]
      trend[, period := as.Date(paste(year, month, "01", sep = "-"))]
      plot_ly(trend, x = ~period, y = ~total_hours, type = "bar",
              marker = list(color = COL_PRIMARY)) |>
        layout(xaxis = list(title = ""), yaxis = list(title = "Hours"),
               margin = list(t = 10))
    })

    # ── Monthly compensation trend ──
    output$monthly_comp_plot <- renderPlotly({
      m <- monthly()
      req(nrow(m) > 0)
      trend <- m[, .(total_comp = sum(total_compensation, na.rm = TRUE)),
                   by = .(year, month)]
      trend[, period := as.Date(paste(year, month, "01", sep = "-"))]
      plot_ly(trend, x = ~period, y = ~total_comp, type = "scatter",
              mode = "lines+markers",
              line = list(color = COL_SUCCESS, width = 2)) |>
        layout(xaxis = list(title = ""), yaxis = list(title = "USD"),
               margin = list(t = 10))
    })

    # ── Top physicians by hours ──
    output$top_physicians_plot <- renderPlotly({
      m <- monthly()
      req(nrow(m) > 0)
      cur_year <- year(Sys.Date())
      top <- m[year == cur_year,
               .(total_hours = sum(total_hours, na.rm = TRUE)), by = physician_name]
      top <- top[order(-total_hours)][1:min(10, nrow(top))]
      plot_ly(top, x = ~total_hours, y = ~reorder(physician_name, total_hours),
              type = "bar", orientation = "h",
              marker = list(color = COL_INFO)) |>
        layout(xaxis = list(title = "Hours"), yaxis = list(title = ""),
               margin = list(t = 10, l = 120))
    })

    # ── Department compensation ──
    output$dept_comp_plot <- renderPlotly({
      d <- dept()
      req(nrow(d) > 0 && "department" %in% names(d))
      cur_year <- year(Sys.Date())
      dsum <- d[year == cur_year,
                .(total_comp = sum(total_compensation, na.rm = TRUE)),
                by = department]
      plot_ly(dsum, labels = ~department, values = ~total_comp,
              type = "pie",
              textinfo = "label+percent") |>
        layout(showlegend = FALSE, margin = list(t = 10))
    })

    # ── Recent uploads table ──
    output$recent_uploads <- renderDT({
      h <- hist()
      datatable(h[1:min(5, nrow(h)), ],
                rownames = FALSE,
                options = list(dom = "t", pageLength = 5))
    })
  })
}

# ── Helper: KPI card HTML ─────────────────────────────────────
kpi_card <- function(title, value, icon_el, color = "primary") {
  div(class = paste0("card border-", color, " mb-3"),
    div(class = "card-body d-flex align-items-center gap-3",
      div(class = paste0("text-", color, " fs-2"), icon_el),
      div(
        div(class = "fw-bold fs-4", value),
        div(class = "text-muted small", title)
      )
    )
  )
}
