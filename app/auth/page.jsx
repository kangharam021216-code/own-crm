"use client";

import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import Link from "next/link";

export default function AuthPage() {
  const [phone, setPhone] = useState("010-");
  const [token, setToken] = useState("");
  const [step, setStep] = useState("phone"); // phone | otp
  const [msg, setMsg] = useState("");

  useEffect(() => {
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) setMsg("로그인 성공! 이제 /dashboard 로 이동하세요.");
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const normalized = useMemo(() => phone.replace(/[^0-9]/g, ""), [phone]);

  async function sendOtp() {
    setMsg("");
    const e164 = normalized.startsWith("82") ? `+${normalized}` : `+82${normalized.replace(/^0/, "")}`;
    const { error } = await supabase.auth.signInWithOtp({ phone: e164 });
    if (error) setMsg(error.message);
    else {
      setStep("otp");
      setMsg("인증번호를 발송했어요. 문자로 받은 코드를 입력하세요.");
    }
  }

  async function verifyOtp() {
    setMsg("");
    const e164 = normalized.startsWith("82") ? `+${normalized}` : `+82${normalized.replace(/^0/, "")}`;
    const { error } = await supabase.auth.verifyOtp({ phone: e164, token, type: "sms" });
    if (error) setMsg(error.message);
    else setMsg("인증 완료!");
  }

  return (
    <main style={{ padding: 24, maxWidth: 520, margin: "0 auto" }}>
      <h2>휴대폰 로그인</h2>
      <p style={{ opacity: 0.8, lineHeight: 1.5 }}>
        관리자 초대 기반입니다. 초대되지 않은 번호는 로그인 후에도 접근이 제한될 수 있어요.
      </p>

      {step === "phone" ? (
        <>
          <label style={label}>휴대폰 번호</label>
          <input value={phone} onChange={(e) => setPhone(e.target.value)} style={input} placeholder="010-0000-0000" />
          <button onClick={sendOtp} style={primaryBtn}>인증번호 받기</button>
        </>
      ) : (
        <>
          <div style={{ marginBottom: 12 }}>
            <div style={{ fontSize: 14, opacity: 0.75 }}>휴대폰: {phone}</div>
            <button onClick={() => setStep("phone")} style={linkBtn}>번호 다시 입력</button>
          </div>
          <label style={label}>인증번호</label>
          <input value={token} onChange={(e) => setToken(e.target.value)} style={input} placeholder="6자리" />
          <button onClick={verifyOtp} style={primaryBtn}>로그인</button>
        </>
      )}

      {msg && <div style={{ marginTop: 12, padding: 12, border: "1px solid #eee", borderRadius: 10 }}>{msg}</div>}

      <div style={{ marginTop: 18 }}>
        <Link href="/" style={linkBtn}>홈으로</Link>
        <span style={{ margin: "0 8px", opacity: 0.5 }}>|</span>
        <Link href="/dashboard" style={linkBtn}>대시보드</Link>
      </div>
    </main>
  );
}

const label = { display: "block", marginTop: 12, marginBottom: 6, fontSize: 14 };
const input = { width: "100%", padding: "12px 10px", borderRadius: 10, border: "1px solid #ddd", fontSize: 16 };
const primaryBtn = { marginTop: 12, width: "100%", padding: "12px 10px", borderRadius: 10, border: "1px solid #111", background: "#111", color: "#fff", fontSize: 16 };
const linkBtn = { background: "none", border: "none", padding: 0, color: "#111", textDecoration: "underline", cursor: "pointer", fontSize: 14 };
