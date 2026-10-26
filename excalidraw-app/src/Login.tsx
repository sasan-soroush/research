import { useState, type FormEvent } from "react";
import { supabase } from "./supabase";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);

  const signIn = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setMessage(null);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setMessage({ text: error.message, error: true });
    setBusy(false);
  };

  // Sign-in only: never creates an account.
  const sendLink = async () => {
    if (!email) return setMessage({ text: "Enter your email first.", error: true });
    setBusy(true);
    setMessage(null);
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: false, emailRedirectTo: location.origin },
    });
    setMessage(error ? { text: error.message, error: true } : { text: "Check your email for a sign-in link." });
    setBusy(false);
  };

  return (
    <div className="center">
      <form className="card login" onSubmit={signIn}>
        <h1>Drawings</h1>
        <label>
          Email
          <input type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          Password
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        <button className="primary" disabled={busy || !password}>
          Sign in
        </button>
        <button type="button" disabled={busy} onClick={sendLink}>
          Email me a sign-in link
        </button>
        {message && <p className={message.error ? "error" : "muted"}>{message.text}</p>}
      </form>
    </div>
  );
}
