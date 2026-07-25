import { createClient } from '@supabase/supabase-js'

const isKeyValid = (key: string | undefined): boolean => {
  return typeof key === 'string' && key.length > 10 && key.startsWith('eyJ')
}

const isUrlValid = (url: string | undefined): boolean => {
  return typeof url === 'string' && url.length > 10 && url.startsWith('http')
}

// Injeta as credenciais de fallback caso as variáveis de ambiente em produção estejam ausentes ou corrompidas
const supabaseUrl = isUrlValid(process.env.NEXT_PUBLIC_SUPABASE_URL)
  ? process.env.NEXT_PUBLIC_SUPABASE_URL!
  : 'https://vshrwpnrckkgvesuqoyk.supabase.co'

const supabaseAnonKey = isKeyValid(process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)
  ? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzaHJ3cG5yY2trZ3Zlc3Vxb3lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMjgxNDEsImV4cCI6MjA5OTcwNDE0MX0.TtSg2aE3GQCS-bgcvpqzo343NCmXuEzga8CpzDuIbBc'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
