@echo off
setlocal
set "PROJECT=C:\Users\morales-fo.j\Nextcloud\my-dissertation\national-AI-validation"
set "RSCRIPT=C:\Users\morales-fo.j\AppData\Local\Programs\R\R-4.5.3\bin\Rscript.exe"
cd /d "%PROJECT%" || exit /b 1
"%RSCRIPT%" R\install_packages.R || exit /b 1
"%RSCRIPT%" R\run_all.R "%PROJECT%" || exit /b 1
"%RSCRIPT%" R\tr_etc_fixed_source.R "%PROJECT%" --overwrite || exit /b 1
cd /d "%PROJECT%\.." || exit /b 1
if not exist "%PROJECT%\report" mkdir "%PROJECT%\report"
(
 echo \documentclass[11pt]{article}
 echo \usepackage[a4paper,margin=1in]{geometry}
 echo \usepackage{amsmath,amssymb,booktabs,graphicx}
 echo \usepackage[T1]{fontenc}
 echo \usepackage{lmodern}
 echo \providecommand{\navdir}{national-AI-validation}
 echo \begin{document}
 echo \input{national-AI-validation/latex/simulation_section.tex}
 echo \clearpage
 echo \input{national-AI-validation/latex/simulation_appendix.tex}
 echo \end{document}
) > "%PROJECT%\report\simulation_section_preview.tex"
pdflatex -interaction=nonstopmode -halt-on-error -output-directory="%PROJECT%\report" "%PROJECT%\report\simulation_section_preview.tex"
pdflatex -interaction=nonstopmode -halt-on-error -output-directory="%PROJECT%\report" "%PROJECT%\report\simulation_section_preview.tex"
echo Done. Preview PDF: "%PROJECT%\report\simulation_section_preview.pdf"
