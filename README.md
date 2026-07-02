# National AI Validation Simulation

This repository contains the reproducible code, simulation documentation, and
generated manuscript outputs for the dissertation chapter:

> **Objective Reference Points, Predictive Representativity, and External Transportability**

The chapter is part of the dissertation:

> **Toward Safe AI**

Author: **Andrés Morales-Forero**

## Overview

This repository implements a methodological simulation study for evaluating
target performance, Predictive Representativity, and external transportability
of a locked predictive system under different Objective Reference Point (ORP)
construction strategies.

The study examines how the design of a target-country audit, the estimator, and
the uncertainty procedure affect the evidence available for regulatory-style
claims about model performance.

The repository is organized so that the simulation workflow, decision criteria,
generated tables, and publication figures can be inspected and reproduced.

## Reporting and reproducibility orientation

The repository is documented using good-practice principles from the following
international reporting and reproducibility frameworks:

- **ADEMP** for simulation studies: Aims, Data-generating mechanisms,
  Estimands, Methods, and Performance measures.
- **TRIPOD+AI** as contextual reporting guidance for prediction-model and
  machine-learning evaluation studies.
- **DECIDE-AI, CONSORT-AI, and SPIRIT-AI** as contextual AI-health reporting
  references. These are not claimed as applicable reporting checklists here,
  because this repository supports a methodological simulation rather than a
  prospective clinical trial or early clinical evaluation study.
- **FAIR principles** for making research objects findable, accessible,
  interoperable, and reusable.

This repository does not claim formal compliance with clinical trial reporting
guidelines. Its purpose is to make the simulation design, stochastic settings,
analysis workflow, and generated outputs transparent and reusable.

Detailed documentation is provided in:

```text
docs/simulation_description.md
docs/reporting_checklist.md