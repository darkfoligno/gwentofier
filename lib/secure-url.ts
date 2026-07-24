const HTTPS_FALLBACK = "/placeholder.svg"

export function secureImageUrl(value?: string | null, fallback = HTTPS_FALLBACK) {
  const normalized = value?.trim()
  if (!normalized) return fallback
  
  if (normalized.includes('ucoz.com.br')) {
    return `https://wsrv.nl/?url=${encodeURIComponent(normalized)}`
  }
  
  return normalized.replace(/^http:\/\//i, "https://")
}
