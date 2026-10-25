# Proofreading app: scan image beside editable OCR text.
# Launch with run_proofread() from R/proofread.R (sets the project root).
# Saves to data/corrections.csv, one row per page (latest save wins).
# Edits are auto-saved when you leave a page; pages you only view are not recorded.
library(shiny)
library(bslib)
library(readr)
library(dplyr)
library(stringr)

root <- getOption("pomeroy.root", normalizePath(".."))
corr_path <- file.path(root, "data", "corrections.csv")
addResourcePath("scan", file.path(root, "data", "pages"))
addResourcePath("review", file.path(root, "data", "pages", "review"))

pages <- read_csv(file.path(root, "output", "pages.csv"), show_col_types = FALSE) |>
  mutate(text_marked = coalesce(text_marked, ""),
         tier_short = str_sub(tier, 1, 1))

empty_corr <- tibble(page_id = character(), status = character(),
                     corrected_text = character(), saved_at = character())

read_corr <- function() {
  if (!file.exists(corr_path)) return(empty_corr)
  read_csv(corr_path, col_types = "cccc", show_col_types = FALSE)
}

write_corr <- function(x) {
  # Write then rename so a crash cannot leave a half-written file
  tmp <- paste0(corr_path, ".tmp")
  write_csv(x, tmp)
  file.rename(tmp, corr_path)
}

# Warn the browser before closing the tab while there are unsaved edits
dirty_js <- "
Shiny.addCustomMessageHandler('dirty', function(isDirty) {
  window.onbeforeunload = isDirty ? function(e) { e.preventDefault(); e.returnValue = ''; return ''; } : null;
});"

ui <- page_sidebar(
  title = "Pomeroy journals: proofreading",
  tags$head(tags$script(HTML(dirty_js))),
  sidebar = sidebar(
    width = 300,
    checkboxGroupInput("tiers", "Tier",
      c("A: manual typing" = "A", "B: proofread" = "B", "C: spot check" = "C"),
      selected = c("A", "B")),
    checkboxGroupInput("vols", "Volume",
      sort(unique(pages$volume)), selected = sort(unique(pages$volume)), inline = TRUE),
    radioButtons("status", "Status", c("All" = "all", "To do" = "todo", "Done" = "done"),
                 inline = TRUE),
    selectInput("page", "Page", choices = NULL),
    layout_columns(
      actionButton("prev", "Previous"),
      actionButton("nxt", "Next")
    ),
    hr(),
    radioButtons("img_type", "Image",
      c("Flagged words boxed (half size)" = "review", "Clean (full resolution)" = "scan")),
    sliderInput("zoom", "Zoom (%)", 50, 250, 100, step = 10),
    hr(),
    textOutput("progress")
  ),
  layout_columns(
    col_widths = c(6, 6),
    card(card_header(textOutput("img_title")), full_screen = TRUE,
         div(style = "overflow:auto; height:78vh;", uiOutput("scan_img"))),
    card(card_header("Text", uiOutput("dirty_badge", inline = TRUE)),
         textAreaInput("txt", NULL, value = "", width = "100%", rows = 28),
         tags$style("#txt {font-family: monospace; font-size: 15px;}"),
         layout_columns(
           actionButton("save", "Save", class = "btn-primary"),
           actionButton("save_next", "Save and next", class = "btn-success"),
           actionButton("reset", "Reset to OCR draft")
         ),
         textOutput("msg"))
  )
)

server <- function(input, output, session) {
  corr <- reactiveVal(read_corr())
  current <- reactiveVal(NULL)
  # Text as last loaded or saved; differs from the box when there are unsaved edits
  loaded <- reactiveVal("")

  draft_for <- function(id) pages$text_marked[pages$page_id == id]

  visible <- reactive({
    done_ids <- corr()$page_id
    keep <- pages |>
      filter(tier_short %in% input$tiers, volume %in% input$vols)
    if (input$status == "todo") keep <- filter(keep, !page_id %in% done_ids)
    if (input$status == "done") keep <- filter(keep, page_id %in% done_ids)
    keep
  })

  is_dirty <- reactive(!is.null(current()) && !identical(input$txt, loaded()))

  # Save text for a given page and record it as the new baseline if it is the open page
  save_page <- function(id, text, note = "Saved") {
    new <- tibble(page_id = id,
                  status = if (identical(text, draft_for(id))) "confirmed" else "edited",
                  corrected_text = text,
                  saved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
    updated <- isolate(corr()) |> filter(page_id != id) |> bind_rows(new) |> arrange(page_id)
    write_corr(updated)
    corr(updated)
    output$msg <- renderText(sprintf("%s %s (%s) at %s", note, id, new$status, new$saved_at))
  }

  # Keep the page dropdown in sync with filters and the current page
  observe({
    v <- visible()
    done_ids <- corr()$page_id
    lab <- sprintf("%s p%d [%s]%s", v$volume, v$page, v$tier_short,
                   if_else(v$page_id %in% done_ids, " done", ""))
    sel <- isolate(current())
    if (is.null(sel) || !sel %in% v$page_id) sel <- v$page_id[1]
    updateSelectInput(session, "page", choices = setNames(v$page_id, lab), selected = sel)
  })

  # Leaving a page with unsaved edits saves them first
  observeEvent(input$page, {
    req(input$page)
    old <- current()
    if (!is.null(old) && old != input$page && !identical(input$txt, loaded())) {
      save_page(old, input$txt, note = "Auto-saved")
    }
    current(input$page)
    saved <- filter(corr(), page_id == input$page)
    start <- if (nrow(saved)) saved$corrected_text[1] else draft_for(input$page)
    loaded(start)
    updateTextAreaInput(session, "txt", value = start)
  })

  step <- function(by) {
    ids <- visible()$page_id
    i <- match(current(), ids)
    if (!is.na(i) && i + by >= 1 && i + by <= length(ids)) {
      updateSelectInput(session, "page", selected = ids[i + by])
    }
  }
  observeEvent(input$prev, step(-1))
  observeEvent(input$nxt, step(1))

  observeEvent(input$save, {
    req(current())
    save_page(current(), input$txt)
    loaded(input$txt)
  })

  observeEvent(input$save_next, {
    req(current())
    ids <- visible()$page_id
    i <- match(current(), ids)
    save_page(current(), input$txt)
    loaded(input$txt)
    if (!is.na(i) && i < length(ids)) updateSelectInput(session, "page", selected = ids[i + 1])
  })

  observeEvent(input$reset, {
    updateTextAreaInput(session, "txt", value = draft_for(current()))
  })

  observe(session$sendCustomMessage("dirty", isTRUE(is_dirty())))

  output$dirty_badge <- renderUI({
    if (isTRUE(is_dirty())) {
      span(class = "badge text-bg-warning ms-2", "Unsaved changes (saved automatically when you change page)")
    } else {
      span(class = "badge text-bg-secondary ms-2", "No unsaved changes")
    }
  })

  output$img_title <- renderText({
    req(current())
    r <- pages[pages$page_id == current(), ]
    sprintf("%s, page %d | tier %s | mean confidence %.0f%% | %s",
            r$volume, r$page, r$tier_short, r$mean_conf, coalesce(r$reason, "no flag"))
  })

  output$scan_img <- renderUI({
    req(current())
    use_review <- input$img_type == "review" &&
      file.exists(file.path(root, "data", "pages", "review", paste0(current(), ".png")))
    src <- sprintf("%s/%s.png", if (use_review) "review" else "scan", current())
    # Fixed display width regardless of file size, so zoom behaves the same for both
    tags$img(src = src, style = sprintf("width:%dpx; max-width:none;", round(10 * input$zoom)))
  })

  output$progress <- renderText({
    v <- pages |> filter(tier_short %in% c("A", "B"))
    sprintf("Tier A/B pages saved: %d of %d", sum(corr()$page_id %in% v$page_id), nrow(v))
  })
}

shinyApp(ui, server)
