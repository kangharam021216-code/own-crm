import Link from "next/link";

export default function Home() {
  return (
    <main style={{ padding: 24, maxWidth: 960, margin: "0 auto" }}>
      <h1 style={{ margin: "0 0 8px" }}>OWN CRM</h1>
      <p style={{ marginTop: 0, opacity: 0.8 }}>빛으로 아트 스토리 · 전시동 (웹서비스 스타터)</p>

      <div style={{ display: "flex", gap: 12, flexWrap: "wrap", marginTop: 16 }}>
        <Link href="/auth" style={btn}>휴대폰 로그인</Link>
        <Link href="/dashboard" style={btn}>대시보드</Link>
        <Link href="/calendar" style={btn}>캘린더</Link>
        <Link href="/bookings" style={btn}>예약</Link>
        <Link href="/customers" style={btn}>고객</Link>
        <Link href="/trash" style={btn}>보관함</Link>
      </div>

      <hr style={{ margin: "24px 0" }} />
      <p style={{ lineHeight: 1.6 }}>
        이 프로젝트는 Supabase(Auth+DB) + Next.js로 구현됩니다. 로그인 후 권한(ADMIN/MANAGER/STAFF/PARTNER)에 따라 메뉴가 달라집니다.
      </p>
    </main>
  );
}

const btn = {
  display: "inline-block",
  padding: "10px 12px",
  borderRadius: 10,
  border: "1px solid #ddd",
  textDecoration: "none",
  color: "#111",
};
