import { createClient } from '@supabase/supabase-js'

// Fallbacks de produção adicionados para blindagem contra variáveis de ambiente ausentes no empacotamento
const supabaseUrl = (process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_URL !== 'undefined')
  ? process.env.NEXT_PUBLIC_SUPABASE_URL 
  : 'https://vshrwpnrckkgvesuqoyk.supabase.co'

const supabaseAnonKey = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY !== 'undefined')
  ? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY 
  : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzaHJ3cG5yY2trZ3Zlc3Vxb3lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMjgxNDEsImV4cCI6MjA5OTcwNDE0MX0.TtSg2aE3GQCS-bgcvpqzo343NCmXuEzga8CpzDuIbBc'

if (!supabaseUrl || supabaseUrl === 'undefined' || !supabaseAnonKey || supabaseAnonKey === 'undefined') {
  throw new Error('Defina NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY com valores validos.')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
