# Hi PG UI/UX Transformation Status

Last audited: 2026-10-31

## Repository reality

- Flutter is the primary product client and already contains broad Owner, Student, Admin, authentication, booking, payment, map, complaint, support, and account flows.
- The Next.js application currently contains public landing, search, PG details, owner dashboard, and admin KYC routes. It does not yet contain the full owner-management or authenticated student route set described in the master brief.
- The original `prototype.html` referenced by the technical plan is not present in this repository. Existing Flutter screens, API contracts, and ADR-0025 are therefore the available UX sources of truth.
- The Spring Boot API remains authoritative. This redesign stage does not change API contracts, database schemas, authorization rules, or payment behavior.

## Completed in this stage

### Shared web design system

- Aligned web colour, radius, shadow, spacing, focus, motion, and reduced-motion behavior with the current Hi PG mobile design language.
- Added a responsive premium site header and footer with discovery, owner, legal, support, and download paths.
- Added reusable page-entry, skeleton, button, form, status, finance, inventory, and metric presentation patterns.

### Student web landing

- Rebuilt the hero as a responsive discovery-first experience with prominent location search.
- Added a live-data property collage; it only uses photos returned by the public discovery API.
- Added verified, map-ready, and clear-pricing trust cues.
- Upgraded stay-category navigation with accessible vector icons and responsive interaction states.
- Preserved the existing real property rails, empty state, API error state, filters, and details navigation.

### Student discovery and property details

- Rebuilt search results as an image-first, responsive property grid with consistent 4:3 media, restrained metadata, transparent monthly pricing, verification state, and real bed availability.
- Added an animated filter dialog for city, gender preference, and monthly rent using Motion for Next.js.
- Added reduced-motion-aware page and staggered-card transitions.
- Rebuilt PG details with a five-image desktop gallery and swipeable, scroll-snapping mobile gallery.
- Added clearer property facts, room and available-bed presentation, live availability, map action, and a sticky booking summary.
- Kept booking in the authenticated mobile app because web student authentication and payment session handling are not implemented yet.

### Owner web dashboard

- Replaced the placeholder route with a real owner sign-in and portfolio dashboard.
- Added server-side session proxy routes using secure, HTTP-only, same-site cookies.
- Added refresh-token rotation and backend logout integration without exposing tokens to browser JavaScript.
- Dashboard metrics come exclusively from `GET /api/v1/owner/dashboard`.
- Added real occupancy, bed inventory, monthly collections, expenses, net position, pending dues, property, customer, and complaint summaries.
- Added responsive loading, error, retry, refresh, and sign-out states.

## Verified

- `npm run lint`
- `npm run build`
- Production Next.js server responds with HTTP 200 for `/` and `/dashboard`.
- Production Next.js server responds with HTTP 200 for `/search` and a real `/pgs/{pgId}` route loaded from the production discovery API.
- Unauthenticated `/api/owner/dashboard` correctly returns HTTP 401.
- `/api/owner/session` reports an unauthenticated state without leaking token data.
- No backend, schema, or mobile functionality was replaced with dummy content.

## Remaining transformation work

### Owner web

- PG, floor, room, bed, customer, fee, expense, complaint, receipt, document, report, and settings routes do not yet exist in Next.js.
- Those routes should be added incrementally against the existing authenticated owner APIs, using the session proxy introduced in this stage.
- Recent activity and time-series charts need dedicated backend read models before they can be implemented honestly; the current dashboard summary only exposes point-in-time totals.

### Student web

- Browser authentication, booking, payment, complaints, notifications, account, saved properties, and history are not wired on web.
- Ratings, favourites, amenities filters, and recently viewed sections require verified backend support before UI is added.
- Public search currently supports city, gender preference, and rent range because those are the backend-backed filters available today.

### Flutter

- The existing premium mobile pass remains in place. A later visual-QA stage should inspect every rendered Owner and Student route on compact, medium, and expanded devices and correct any screen-specific overflow or hierarchy issues.

## Implementation rule for subsequent stages

Complete one functional vertical slice at a time: route, authenticated API integration, responsive states, accessibility, tests, and rendered QA. Do not add dashboard tiles, charts, filters, ratings, availability, or financial values that are not backed by the current API.
