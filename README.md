# Flexible Workflow Approval Status in SAP GUI (VA03)

Deutsche Version: [README.de.md](README.de.md)

Shows the status of the SAP S/4HANA **flexible workflow** for sales documents (delivered for
credit memo requests) directly in transaction VA03, so that users who work in SAP GUI do not
have to open the Fiori app to see whether a document is approved, rejected or still waiting.

The solution consists of two modules:

| Module | What you get | Touches the SAP standard? |
|---|---|---|
| **Core** (mandatory) | A header tab "Approval" in VA03 with a tree of all workflow runs and their steps: processor, status, decision, time stamps and the note (decision comment) of each step, which opens on double-click. Plus a report that shows the same data as an ALV list. | No. It uses the released BAdI BADI_SLS_HEAD_SCR_CUS and own objects only. |
| **Status button** (optional) | An icon button in the VA03 toolbar (pending, rework, approved, rejected, cancelled) with a quick info such as "Approval pending with Jane Doe". A click opens the tab. | Yes. Two implicit enhancements in SAPMV45A and a copy of a standard GUI status. Companies that keep their SAP standard untouched skip this module; the tab is then reached through the header detail of the document. |

No customer tables are involved. Everything is read at runtime from SAP Business Workflow.

## Screenshots

Header tab "Approval" with the workflow runs and steps (core module):

![Approval tab in VA03](docs/images/result_va03_approval_tab.png)

Status button in the VA03 toolbar, here with the icon for "approved" and its quick info (optional module):

![Status button in VA03](docs/images/result_va03_overview_status_button.png)

## Requirements

- SAP S/4HANA (on-premise or private cloud) with the flexible workflow for credit memo requests
  activated: SAP standard workflow scenario WS02000029 with its dialog tasks TS02000054 and
  TS02000055 (workflow object type CL_SD_CMR_WORKFLOW).
  Developed and tested on S/4HANA 2023 (S4CORE 108, SAP_BASIS 758).
- SAP GUI for Windows / Java (the tab uses a SALV tree control)
- ABAP 7.54 or higher (inline declarations, constructor expressions, ABAP Doc)
- abapGit is convenient but not required: [docs/INSTALLATION.md](docs/INSTALLATION.md) describes
  both ways.

## Components

| Object | Type | Module | Role |
|---|---|---|---|
| ZCL_SD_APM_WF_SCOPE | Class | core | Defines for which transaction and document categories the integration is active |
| ZCL_SD_APM_WF_READER | Class | core | Reads runs and steps of the workflow for one document (single data source) |
| ZCL_SD_APM_HEAD_TAB | Class | core | BAdI implementation of BADI_SLS_HEAD_SCR_CUS: registers the header tab |
| ZSD_APM_INFO | Function group | core | Subscreen 0100 (SALV tree), function modules; GUI status ZU for the optional button |
| ZSD_APM | Message class | core | All UI texts in German, English translation table for SE63 in docs/MESSAGES.md |
| ZSD_APM_WF_DISPLAY | Report | core | Shows the workflow of one document as ALV list, useful for verification and support |
| ZSD_APM_WF_FCODE | Enhancement | status button | Source code plug-in in SAPMV45A: button click navigates to the tab |
| ZSD_APM_WF_GUI_STATUS | Enhancement | status button | Source code plug-in in SAPMV45A: sets GUI status ZU with the button |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces work together and
[docs/INSTALLATION.md](docs/INSTALLATION.md) for the installation steps.

## Installation in short

1. Pull with abapGit: all objects including subscreen, GUI status, BAdI implementation and
   the two plug-ins are created (uncheck the plug-ins in the pull dialog if you do not want the
   status button). Without abapGit, create the objects manually from the files in `/src/`;
   both ways are described step by step in INSTALLATION.md.
2. Create the application log object ZSD_APM / WF_DISPLAY in SLG0 and check the workflow
   constants (part B3, B4).
3. Run report ZSD_APM_WF_DISPLAY for a credit memo request, then open it in VA03.

## Extending the scope

The document categories are defined in one place, `ZCL_SD_APM_WF_SCOPE=>GET_DOC_CATEGORIES`.
Add further categories from interface IF_SD_DOC_CATEGORY (for example sales orders) or replace
the constant list by a customizing table. The reader then needs the workflow object type and
the task ids of that category (constants `GC_TYPEID` and `GC_TASK` in `ZCL_SD_APM_WF_READER`).

## Contributing

Pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. The repository
is checked with [abaplint](https://abaplint.org) on every push.

## Maintainer

Developed and maintained by [M2 Digital GmbH](https://www.m2-digital.ch), Tägerwilen, Switzerland.
Bug reports and feature requests belong in the GitHub issues, pull requests are welcome. For
questions that go beyond the repository, for example other document categories or a Fiori
counterpart, write to [info@m2-digital.ch](mailto:info@m2-digital.ch).

## License

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 M2 Digital GmbH. Free to use, modify and
distribute, also commercially; the license text and copyright notice have to be kept.
