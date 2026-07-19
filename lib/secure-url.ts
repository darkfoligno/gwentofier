const HTTPS_FALLBACK = "/placeholder.svg"

export function secureImageUrl(value?: string | null, fallback = HTTPS_FALLBACK) {
  const normalized = value?.trim()
  if (!normalized) return fallback
  return normalized.replace(/^http:\/\//i, "https://")
}
