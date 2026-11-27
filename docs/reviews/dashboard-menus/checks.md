# Dashboard menu checks

The browser walkthrough renders the dashboard components with synthetic local data. Browser navigation, focus, selected states, form validation and responsive CSS run in Chromium. Authentication, Intune reads and mutations use fixture adapters. External targets were inspected for their destinations and protocols. A live Microsoft sign-in, webhook delivery or tenant deployment was outside the walkthrough.

| Coverage | Result |
| --- | --- |
| Navigation, filters and links | 64 scenario runs passed across desktop and phone in light and dark. Each run checked an interaction sequence, including sidebar and subsection highlights, the palette’s 15 selectable destinations from an app workspace, account themes, Settings tabs, Reports date ranges and opening an app from More actions. |
| Keyboard shortcuts and menu actions | 18 desktop and phone scenario runs passed. These exercised all nine two-key navigation shortcuts, page search, catalog sorting, update filters and sorting, tenant policy and scope callbacks, install dates, Activity filters, revision-specific group review, discovery filters and account sign-out through the local auth adapter. |
| App drawers and secondary menus | 30 desktop and phone scenario runs passed. These covered group editing, detailed install results, installation policy and date editors, pilot review and start actions, discovery linking and removal dialogs, the custom app form, Home scope links, Curated apps and the unsupported startup-report deep link. |
| Webhook form | Add, edit, enable, disable, send test, cancel deletion and confirm deletion passed in a local in-memory service at both widths. All four channel types, custom headers, the secret visibility control and focus restoration were exercised. |
| Help and direct links | Opened 23 guides and selected all 106 steps. Followed 39 distinct internal destinations and checked nine external targets without sending tenant information. |
| Focus and touch | Verified initial palette input focus, focus restoration after Escape, the mobile sidebar focus trap and return to its opener, tooltip activation on a phone and keyboard, and return to the webhook opener. |
| Screenshot coverage | 35 states × 2 sizes × 2 themes, before and after. Desktop is 1440 × 900. Phone is 390 × 844. |
| Patch application | All 13 patches applied to the clean pinned upstream revision. Checked file ownership across patches and compared all 53 edited source files byte for byte with the tested tree. |
| Repository Help review | The help-writer reviewed the dashboard menus, verified the labels and timer values, and synchronized Help and the illustrated steps. The final Help check found 545 on-screen labels. |

[Per-menu changes](README.md) · [Screenshot comparisons](screenshots.md)
