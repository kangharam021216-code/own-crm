export default function Page() {
  return (
    <main style={{padding: 24, maxWidth: 960, margin: "0 auto"}}>
      <h2 style={{marginTop: 0}}>대시보드</h2>
      <p style={{lineHeight: 1.6, opacity: 0.85}}>오늘 문의/이번달 문의/오늘 일정/홀드 만료 임박을 보여줍니다. (홀드 기본 7일)</p>
      <p style={{opacity: 0.7}}>이 페이지는 스타터 뼈대입니다. 실제 데이터 연동(쿼리/권한/필터)은 다음 단계에서 채웁니다.</p>
    </main>
  );
}
