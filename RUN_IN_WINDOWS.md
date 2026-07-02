# Running the R workflow on Windows

From CMD:

```bat
cd /d "C:\Users\morales-fo.j\Nextcloud\my-dissertation\national-AI-validation"
"C:\Users\morales-fo.j\AppData\Local\Programs\R\R-4.5.3\bin\Rscript.exe" R\run_all.R "%C:\Users\morales-fo.j\Nextcloud\my-dissertation\national-AI-validation%"
```

To regenerate only tables and figures from existing R outputs:

```bat
"C:\Users\morales-fo.j\AppData\Local\Programs\R\R-4.5.3\bin\Rscript.exe" -e "source('R/make_tables.R'); make_tables_R(normalizePath(getwd(), winslash='/'))"
"C:\Users\morales-fo.j\AppData\Local\Programs\R\R-4.5.3\bin\Rscript.exe" -e "source('R/dgp.R'); source('R/make_figures.R'); make_figures_R(normalizePath(getwd(), winslash='/'))"
"C:\Users\morales-fo.j\AppData\Local\Programs\R\R-4.5.3\bin\Rscript.exe" R\tr_etc_fixed_source.R "%C:\Users\morales-fo.j\Nextcloud\my-dissertation\national-AI-validation%" --overwrite
```

Manuscript tables and figures are generated from the R summaries, especially `results/summary/performance_summary_R.csv`.
