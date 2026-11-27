# Screenshot review

Gemini 4 Neon reviewed 28 comparison sheets covering the 35 dashboard states at desktop and phone widths in both themes. It received fictional screenshots and used its read-only image viewer. The table records what we could reproduce and how we checked the result.

| Observation | Verification and outcome |
| --- | --- |
| The phone header covers the catalog filter heading. | Confirmed. The drawer was inside the page stacking context. It now renders in a portal above the header, with a single visible Filters heading. Chromium hit-testing reaches the heading at 390px. |
| The phone account menu extends past the right edge. | Confirmed. The expanded sidebar used desktop popover positioning on phones. The phone menu now opens above the trigger. The full menu fits inside 390px in both themes. |
| The update type menu touches the phone edge. | Confirmed. The type and sort menus now reserve eight pixels around the viewport. |
| Phone search lacks a close control. Settings and guides are absent from the visible results. | Added a tappable Close search button. The palette initially shows part of a scrollable list. Keyboard and search tests reach Settings and Help. |
| The header retains a cart icon. | The button already had the accessible name Deployment list. It now also uses a list icon and a hover title. |
| Some screenshots show Inventory instead of an open Deployment list. | Reproduced in the capture sequence. A fresh check waits for the drawer's Close Deployment list button before taking the screenshot. The trigger opened the drawer at both widths in both themes. |
| Progress labels and the assignment error crowd each other on phones. | The progress control now has room for all stages and scrolls within the card. The failed stage and error code stack on phones. The current stage and time remain visible below the strip. |
| The pilot approval dialog lacks margins. Some pilot rows show a bare version arrow. | The dialog now has a phone margin and inner padding. The title falls back to the package identifier or a plain unavailable label when app metadata is missing, and shows an arrow only when a previous version exists. A missing field in a fixture does not establish that a live pilot is missing metadata. |
| Amber warning text is faint in light mode. | The warning text utility used the same bright amber in both themes. Light surfaces now use a darker amber for warning text. |
| Long permission identifiers wrap, the policy selector clips and the update footer wraps. | Permission names remain selectable as full Microsoft Graph identifiers. The selected shared scope now reads “All apps with Auto-update on”. Footer actions can wrap on phones to preserve their touch targets. |
| Inventory, Settings, discovery and Activity read more clearly after the changes. | The comparisons show the compact inventory totals, neutral grouped changes, full Settings tab labels, two-column webhook choices, collapsed discovery guide and single set of deployment counts. The publisher filter uses a native select. Its operating-system popup is outside the screenshot matrix. |

The browser checks cover keyboard focus, dismissal, navigation, filter effects and fixture callbacks. The screenshots establish layout and visible text. Tenant authorization and live delivery were outside the visual review.

[Before and after](screenshots.md) · [Interaction checks](checks.md)
