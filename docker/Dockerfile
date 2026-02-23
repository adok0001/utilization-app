# ============================================================
# Dockerfile — Physician Utilization App
# ============================================================

FROM rocker/shiny:4.4.0

LABEL maintainer="Physician Analytics Team"
LABEL description="Physician Utilization & Compensation Reporting App"

# ── System dependencies ──────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsqlite3-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    pandoc \
    quarto \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ── R package installation (via renv) ───────────────────────
WORKDIR /app

# Copy renv infrastructure first (for layer caching)
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R

RUN R -e "install.packages('renv', repos='https://cran.rstudio.com/')" \
 && R -e "renv::restore()"

# ── Copy application source ──────────────────────────────────
COPY . .

# ── Create data and log directories ─────────────────────────
RUN mkdir -p data logs reports/output

# ── Set permissions ───────────────────────────────────────────
RUN chown -R shiny:shiny /app

# ── Port & launch ────────────────────────────────────────────
EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/app/R/app.R', host='0.0.0.0', port=3838)"]
