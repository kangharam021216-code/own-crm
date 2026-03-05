export default function Page() {
  return (
    <main style={{padding: 24, maxWidth: 960, margin: "0 auto"}}>
      <h2 style={{marginTop: 0}}>보관함</h2>
      <p style={{lineHeight: 1.6, opacity: 0.85}}>삭제는 보관 처리 후 보관함에서 복구/완전삭제. 완전삭제는 MANAGER 이상.</p>
      <p style={{opacity: 0.7}}>이 페이지는 스타터 뼈대입니다. 실제 데이터 연동(쿼리/권한/필터)은 다음 단계에서 채웁니다.</p>
    </main>
  );
}
