\# Reporting and Reproducibility Checklist



This checklist documents how the repository supports transparent reporting for

the simulation study in the dissertation chapter:



> \*\*Objective Reference Points, Predictive Representativity, and External Transportability\*\*



The checklist is organized around ADEMP for simulation studies and FAIR-inspired

repository documentation.



\## 1. ADEMP simulation reporting



| Item | Repository location | Status |

|---|---|---|

| Aims are stated | `docs/simulation\_description.md` | Reported |

| Data-generating mechanism is described | `docs/simulation\_description.md`, `R/dgp.R` | Reported |

| Estimands are defined | `docs/simulation\_description.md`, dissertation chapter | Reported |

| Methods/designs are identified | `R/designs.R`, `R/estimators.R`, `R/run.R` | Reported in code and documentation |

| Performance measures are identified | `R/analyse.R`, `R/validate.R`, `docs/simulation\_description.md` | Reported |

| Monte Carlo summaries are stored | `results/summary/` | Reported |

| Tables are generated reproducibly | `R/make\_tables.R`, `tables/` | Reported |

| Figures are generated reproducibly | `R/make\_figures.R`, `R/tr\_etc\_fixed\_source.R`, `figures/r\_publication/` | Reported |

| Random seeds are documented | `docs/simulation\_description.md` | To complete after seed search |

| Raw replication files are handled transparently | `.gitignore`, `README.md` | Reported |



\## 2. Prediction-model / AI reporting orientation



The repository is not a clinical prediction-model development report and is not

a clinical trial. However, it follows the spirit of transparent AI evaluation

reporting by documenting:



| Item | Repository location | Status |

|---|---|---|

| Locked predictive system assumed | Dissertation chapter, simulation description | Reported |

| Target performance claims specified | Dissertation chapter, simulation description | Reported |

| Target population / target condition represented | Dissertation chapter, `R/dgp.R` | Reported |

| Subgroup estimands represented | `R/dgp.R`, `R/analyse.R`, simulation description | Reported |

| Uncertainty intervals reported | `R/analyse.R`, `R/tr\_etc\_fixed\_source.R`, figures/tables | Reported |

| Decision thresholds specified | `R/tr\_etc\_fixed\_source.R`, simulation description | Reported |

| Limitations of applicability stated | Dissertation chapter, README | Reported |



\## 3. FAIR-inspired repository practices



| FAIR principle | Repository implementation |

|---|---|

| Findable | Repository has descriptive README, structured folders, and citation metadata can be added through `CITATION.cff`. |

| Accessible | Code, summary outputs, tables, and figures are available in the GitHub repository. |

| Interoperable | Outputs use common formats: CSV, TEX, PDF, PNG, SVG, R scripts, Markdown. |

| Reusable | Workflow commands, dependencies, and generated outputs are documented. Raw replication files are excluded but regenerable. |



\## 4. Non-applicable reporting standards



The following standards are relevant context but are not claimed as applicable

checklists for this repository:



| Standard / guidance | Reason for non-applicability |

|---|---|

| CONSORT-AI | The study is not a randomized clinical trial of an AI intervention. |

| SPIRIT-AI | The study is not a clinical trial protocol. |

| DECIDE-AI | The study is not an early-stage clinical evaluation of an AI decision-support system. |

| TRIPOD+AI | The study concerns methodological validation and simulation, not a full clinical prediction-model development or validation report. |



These guidelines are cited as contextual references for transparent AI and

prediction-model evaluation, not as formal compliance claims.

