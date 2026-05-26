/**
 * SIERCP Cloud Functions — entrypoint
 *
 * Exports all callable and webhook functions.
 * Each domain lives in its own file for maintainability.
 */

export { deleteAuthUser }         from "./auth/deleteAuthUser";
export {
  createStripePaymentIntent,
  confirmStripeSubscription,
  cancelStripeSubscription,
  getSubscriptionStatus,
  stripeWebhook,
}                                  from "./payments/stripe";
export { onUserCreated }          from "./auth/onUserCreated";
export { onCertificateApproved }  from "./certificates/onCertificateApproved";
export { onSessionCompleted }     from "./leaderboard/onSessionCompleted";
export { migrateLeaderboards }    from "./leaderboard/migrateLeaderboards";

// ── Web checkout (SIERCP-WEB) ─────────────────────────────────────────────────
export { createCorporatePlanOrderWeb } from "./web/createCorporatePlanOrderWeb";
export { provisionCorporateAccount }   from "./web/provisionCorporateAccount";
