import { useState, type FormEvent } from 'react'
import { motion } from 'framer-motion'
import { ArrowRight } from 'lucide-react'
import { passwordRecoveryRedirect } from '../lib/authRedirect'
import { isSupabaseConfigured, supabase } from '../lib/supabase'

type AuthMode = 'login' | 'signup' | 'forgot' | 'recovery'

interface AuthResult {
  error: { message: string } | null
}

interface AuthClient {
  signInWithPassword(credentials: { email: string; password: string }): Promise<AuthResult>
  signUp(credentials: { email: string; password: string; options: { data: { full_name: string } } }): Promise<AuthResult>
  resetPasswordForEmail(email: string, options: { redirectTo: string }): Promise<AuthResult>
  updateUser(attributes: { password: string }): Promise<AuthResult>
}

export interface LoginProps {
  recovery?: boolean
  onRecoveryComplete?: () => void
}

export default function Login({ recovery = false, onRecoveryComplete }: LoginProps) {
  const [mode, setMode] = useState<AuthMode>(recovery ? 'recovery' : 'login')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [isError, setIsError] = useState(false)
  const auth = supabase.auth as unknown as AuthClient

  function changeMode(next: AuthMode) {
    setMessage('')
    setIsError(false)
    setMode(next)
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setBusy(true)
    setMessage('')
    setIsError(false)
    const data = new FormData(event.currentTarget)
    const email = String(data.get('email') ?? '')
    const password = String(data.get('password') ?? '')

    if (mode === 'forgot') {
      const result = await auth.resetPasswordForEmail(email, { redirectTo: passwordRecoveryRedirect() })
      setIsError(Boolean(result.error))
      setMessage(result.error?.message ?? 'Enviamos o link de recuperação. Confira sua caixa de entrada e o spam.')
      setBusy(false)
      return
    }

    if (mode === 'recovery') {
      if (password !== String(data.get('passwordConfirmation') ?? '')) {
        setIsError(true)
        setMessage('As senhas não coincidem.')
        setBusy(false)
        return
      }
      const result = await auth.updateUser({ password })
      setIsError(Boolean(result.error))
      setMessage(result.error?.message ?? 'Senha atualizada com sucesso.')
      setBusy(false)
      if (!result.error) onRecoveryComplete?.()
      return
    }

    const result = mode === 'login'
      ? await auth.signInWithPassword({ email, password })
      : await auth.signUp({ email, password, options: { data: { full_name: String(data.get('name') ?? '') } } })
    setIsError(Boolean(result.error))
    setMessage(result.error?.message ?? (mode === 'signup' ? 'Cadastro realizado. Confira seu e-mail.' : ''))
    setBusy(false)
  }

  const title = mode === 'login'
    ? 'Bem-vinda de volta'
    : mode === 'signup'
      ? 'Crie sua conta'
      : mode === 'forgot'
        ? 'Recupere sua senha'
        : 'Defina uma nova senha'

  return (
    <div className="flex min-h-screen bg-background">
      <div className="relative hidden w-[46%] flex-col justify-between overflow-hidden bg-forest-800 p-12 lg:flex">
        <div className="pointer-events-none absolute -right-40 -top-40 h-[480px] w-[480px] rounded-full opacity-[0.07]" style={{ background: 'radial-gradient(circle, #d9a44a, transparent 65%)' }} />
        <div className="pointer-events-none absolute -bottom-52 -left-32 h-[520px] w-[520px] rounded-full opacity-10" style={{ background: 'radial-gradient(circle, #749966, transparent 65%)' }} />
        <div className="flex items-center gap-3">
          <img src="./app-icon.png" alt="BSNutri" className="h-12 w-12 rounded-full ring-2 ring-amber-400/60" />
          <span className="font-display text-xl font-semibold text-cream-50">BSNutri</span>
        </div>
        <div className="relative">
          <p className="eyebrow mb-4 !text-amber-300">Planejamento nutricional</p>
          <h1 className="font-display text-[44px] font-medium leading-[1.08] text-cream-50">
            Planos alimentares que o paciente <em className="italic text-amber-300">segue de verdade</em>.
          </h1>
          <p className="mt-5 max-w-md text-[16px] leading-relaxed text-cream-100/70">
            Planeje, revise e publique o cuidado nutricional em um espaço seguro para sua equipe e seus pacientes.
          </p>
        </div>
        <img src="./app-icon.png" alt="" className="relative h-56 w-56 self-center rounded-full shadow-warm-lg" />
        <p className="font-mono text-[11px] uppercase tracking-[0.14em] text-cream-100/40">BSNutri · Nutrição integrada</p>
      </div>

      <div className="flex flex-1 items-center justify-center p-8">
        <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="w-full max-w-sm">
          <img src="./app-icon.png" alt="BSNutri" className="mb-6 h-16 w-16 rounded-full lg:hidden" />
          <p className="eyebrow mb-2">Acesso seguro</p>
          <h2 className="font-display text-3xl font-semibold">{title}</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            {mode === 'login' && 'Entre para continuar o atendimento nutricional.'}
            {mode === 'signup' && 'Depois do cadastro, confirme seu e-mail para liberar o acesso.'}
            {mode === 'forgot' && 'Informe seu e-mail para receber um link seguro.'}
            {mode === 'recovery' && 'Crie uma senha com pelo menos 8 caracteres.'}
          </p>

          {!isSupabaseConfigured && (
            <p className="mt-5 rounded-xl border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900" role="alert">
              A autenticação ainda não foi configurada neste ambiente.
            </p>
          )}

          <form className="mt-8 space-y-4" onSubmit={submit}>
            {mode === 'signup' && (
              <div>
                <label className="label-warm" htmlFor="auth-name">Nome completo</label>
                <input id="auth-name" className="input-warm" name="name" autoComplete="name" required minLength={2} />
              </div>
            )}
            {mode !== 'recovery' && (
              <div>
                <label className="label-warm" htmlFor="auth-email">E-mail</label>
                <input id="auth-email" className="input-warm" name="email" type="email" autoComplete="email" required />
              </div>
            )}
            {mode !== 'forgot' && (
              <div>
                <label className="label-warm" htmlFor="auth-password">Senha</label>
                <input id="auth-password" className="input-warm" name="password" type="password" autoComplete={mode === 'login' ? 'current-password' : 'new-password'} minLength={8} required />
              </div>
            )}
            {mode === 'recovery' && (
              <div>
                <label className="label-warm" htmlFor="auth-password-confirmation">Confirme a nova senha</label>
                <input id="auth-password-confirmation" className="input-warm" name="passwordConfirmation" type="password" autoComplete="new-password" minLength={8} required />
              </div>
            )}
            {message && <p className={`text-sm ${isError ? 'text-destructive' : 'text-forest-700'}`} role={isError ? 'alert' : 'status'}>{message}</p>}
            <button type="submit" className="btn-primary w-full !py-3" disabled={busy || !isSupabaseConfigured}>
              {busy ? 'Aguarde...' : mode === 'login' ? <>Entrar no consultório <ArrowRight size={16} /></> : mode === 'signup' ? 'Cadastrar' : mode === 'forgot' ? 'Enviar link de recuperação' : 'Atualizar senha'}
            </button>
          </form>

          {mode === 'login' && (
            <div className="mt-5 flex flex-col items-center gap-2">
              <button type="button" className="btn-ghost w-full" onClick={() => changeMode('signup')}>Criar minha conta</button>
              <button type="button" className="text-sm font-medium text-forest-700 underline-offset-4 hover:underline" onClick={() => changeMode('forgot')}>Esqueci minha senha</button>
            </div>
          )}
          {mode === 'signup' && <button type="button" className="mt-5 w-full text-sm font-medium text-forest-700" onClick={() => changeMode('login')}>Já tenho uma conta</button>}
          {mode === 'forgot' && <button type="button" className="mt-5 w-full text-sm font-medium text-forest-700" onClick={() => changeMode('login')}>Voltar para entrar</button>}
        </motion.div>
      </div>
    </div>
  )
}
