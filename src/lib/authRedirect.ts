export function passwordRecoveryRedirect(): string {
  return new URL(import.meta.env.BASE_URL, window.location.origin).toString()
}
