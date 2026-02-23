# ============================================================
# upload_module.R — File upload, validation, and approval workflow
# ============================================================

# ── UI ────────────────────────────────────────────────────────
uploadUI <- function(id) {
  ns <- NS(id)
  tagList(
    h2("Upload Physician Data", class = "page-title"),
    fluidRow(
      # Left: upload card
      column(5,
        card(
          card_header("Select File"),
          card_body(
            fileInput(ns("file"), label = NULL,
                      accept = c(".csv", ".xlsx", ".xls"),
                      buttonLabel = "Browse…",
                      placeholder = "or drag & drop CSV / XLSX"),
            uiOutput(ns("file_info")),
            hr(),
            actionButton(ns("validate_btn"), "Validate",
                         class = "btn-primary me-2", icon = icon("check-circle")),
            actionButton(ns("commit_btn"), "Commit to Database",
                         class = "btn-success", icon = icon("database"),
                         disabled = TRUE)
          )
        ),
        uiOutput(ns("validation_status_card"))
      ),
      # Right: preview / issues
      column(7,
        card(
          card_header("Data Preview (first 10 rows)"),
          card_body(
            uiOutput(ns("preview_ui"))
          )
        ),
        uiOutput(ns("issues_card"))
      )
    ),
    hr(),
    h4("Recent Uploads"),
    DTOutput(ns("upload_history"))
  )
}

# ── Server ────────────────────────────────────────────────────
uploadServer <- function(id, r) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    state <- reactiveValues(
      raw_dt           = NULL,
      validation_result = NULL,
      file_hash        = NULL,
      can_commit       = FALSE
    )

    # ── File info ──
    output$file_info <- renderUI({
      req(input$file)
      tags$small(class = "text-muted",
        icon("file"), " ", input$file$name, " · ",
        format(file.size(input$file$datapath), big.mark = ","), " bytes"
      )
    })

    # ── Validate button ──
    observeEvent(input$validate_btn, {
      req(input$file)

      withProgress(message = "Validating file…", value = 0, {
        incProgress(0.2, detail = "Reading file…")
        dt <- tryCatch(
          read_upload(input$file$datapath, input$file$name),
          error = function(e) { showNotification(e$message, type = "error"); NULL }
        )
        req(dt)

        incProgress(0.4, detail = "Running validation rules…")
        vr <- validate_upload(dt, input$file$name)
        state$raw_dt            <- dt
        state$validation_result <- vr
        state$file_hash         <- file_hash(input$file$datapath)
        state$can_commit        <- vr$pass

        incProgress(0.4, detail = "Done.")
      })

      shinyjs::toggleState("commit_btn", condition = state$can_commit)
      log_action("validate_file", input$file$name, session)
    })

    # ── Preview ──
    output$preview_ui <- renderUI({
      req(state$raw_dt)
      DTOutput(ns("preview_table"))
    })

    output$preview_table <- renderDT({
      req(state$raw_dt)
      datatable(preview_upload(state$raw_dt),
                options = list(scrollX = TRUE, dom = "t"),
                rownames = FALSE)
    })

    # ── Validation status card ──
    output$validation_status_card <- renderUI({
      req(state$validation_result)
      vr    <- state$validation_result
      color <- if (vr$pass) "success" else "danger"
      icon_name <- if (vr$pass) "circle-check" else "circle-xmark"
      card(
        card_header(tagList(icon(icon_name), " Validation Result")),
        card_body(
          p(class = paste0("text-", color, " fw-bold"), vr$summary),
          if (!vr$pass)
            p(class = "text-muted small",
              "Fix errors before committing, or use Override to force-load warnings only.")
        ),
        class = paste0("border-", color)
      )
    })

    # ── Issues table ──
    output$issues_card <- renderUI({
      req(state$validation_result)
      if (nrow(state$validation_result$issues) == 0) return(NULL)
      card(
        card_header("Validation Issues"),
        card_body(DTOutput(ns("issues_table")))
      )
    })

    output$issues_table <- renderDT({
      req(state$validation_result)
      report <- format_validation_report(state$validation_result)
      datatable(report,
                rownames = FALSE,
                options  = list(pageLength = 10, scrollX = TRUE)) |>
        formatStyle("Severity",
                    backgroundColor = styleEqual(c("ERROR", "WARNING"),
                                                 c("#fce4e4", "#fff3cd")))
    })

    # ── Commit button ──
    observeEvent(input$commit_btn, {
      req(state$raw_dt, state$validation_result$pass)

      # Duplicate check
      if (is_duplicate_upload(r$db_con, state$file_hash)) {
        showModal(modalDialog(
          title = "Duplicate File Detected",
          "This file appears to have been uploaded previously. Proceed anyway?",
          footer = tagList(
            modalButton("Cancel"),
            actionButton(ns("force_commit"), "Commit Anyway", class = "btn-warning")
          )
        ))
        return()
      }
      do_commit(session, r, state, input$file$name)
    })

    observeEvent(input$force_commit, {
      removeModal()
      do_commit(session, r, state, input$file$name)
    })

    # ── Upload history ──
    output$upload_history <- renderDT({
      r$upload_ts
      hist <- get_upload_history(r$db_con)
      datatable(hist, rownames = FALSE,
                options = list(pageLength = 5, dom = "tp"))
    })
  })
}

# ── Helper: perform the actual commit ────────────────────────
do_commit <- function(session, r, state, file_name) {
  withProgress(message = "Loading data…", value = 0, {
    incProgress(0.3, detail = "Cleaning data…")
    clean_dt <- clean_and_standardise(state$raw_dt)

    incProgress(0.3, detail = "Writing to database…")
    upload_id <- insert_upload_log(
      r$db_con,
      file_name  = file_name,
      file_hash  = state$file_hash,
      n_rows     = nrow(clean_dt),
      n_errors   = state$validation_result$n_errors,
      n_warnings = state$validation_result$n_warnings,
      status     = "success",
      uploaded_by = session$user %||% "anonymous"
    )
    persist_upload(r$db_con, clean_dt)

    incProgress(0.4, detail = "Updating dashboards…")
    r$upload_ts <- Sys.time()  # trigger reactive refresh
  })

  showNotification(
    glue::glue("✓ {nrow(clean_dt)} records loaded from {file_name}"),
    type = "message", duration = 5
  )
  log_action("commit_upload", file_name, session)
}
