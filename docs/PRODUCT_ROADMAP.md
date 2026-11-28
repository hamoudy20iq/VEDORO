# VEDORO Product Roadmap

This roadmap tracks the 12 requested product areas. Features are delivered incrementally; a checkbox is only marked complete after implementation and verification.

## Phase 1 — Video foundation
- [ ] Personalized recommendation feed (watch time, completion, likes, follows, freshness, safety filters)
- [ ] Video delivery improvements (thumbnails, adaptive/transcoded renditions, resumable uploads, CDN strategy)
- [ ] Creator analytics (views, unique viewers where measurable, watch time, completion, engagement)

## Phase 2 — Discovery and creation
- [ ] Video editor (trim, cover selection, captions/text, audio, filters; validate platform capabilities)
- [ ] Hashtags, searchable topics, trending lists, and discovery pages
- [ ] Push notifications with user preferences and delivery-token lifecycle

## Phase 3 — Social and trust
- [ ] Account privacy controls (private accounts, follow approvals, audience controls, comment/DM controls)
- [ ] Communities (public/private groups, membership, roles, moderation)
- [ ] Verification requests and admin review workflow

## Phase 4 — Operations and monetization
- [ ] Admin dashboard (users, posts, reports, moderation queue, platform health and audit trail)
- [ ] Creator earnings, gifts, payout requests, fraud controls, transparent ledger and admin approval

## Phase 5 — Live
- [ ] Live streaming (provider integration, stream lifecycle, chat moderation, viewer counts, reporting)

## Existing foundations
- Authentication, profiles, follows, feed posts, likes/comments, saved posts
- Stories, story reactions/views, direct messages, media attachments, read receipts
- Message reactions, replies, typing status, sender-only message deletion
- Blocking and moderation/reporting foundations

## Delivery and safety gates
1. Every database change must include least-privilege grants and tested RLS policies.
2. Never expose service-role credentials in the mobile app.
3. Every feature must include loading, empty, error, and permission-denied states.
4. Run static analysis and Android APK build after each coherent milestone.
5. Verify the generated APK artifact belongs to the latest tested commit before calling it ready.
6. Monetization and payouts require ledger reconciliation, fraud review, and explicit admin controls.
7. Live streaming and video processing require an external provider/CDN decision; do not fake these features with local-only UI.
