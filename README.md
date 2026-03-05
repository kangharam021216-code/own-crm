# OWN CRM (빛으로 아트 스토리 · 전시동) — 웹서비스 스타터 패키지

이 폴더는 **직원 여러명이 동시에 사용하는 웹사이트형 CRM**을 빠르게 만들기 위한 “출발점(Starter)”입니다.
- 로그인: 휴대폰 OTP (Supabase Auth)
- 가입: 관리자 초대(Invite Only)
- 지점/홀: 빛으로 아트 스토리 / 전시동 (시드 데이터 포함)
- 웨딩 슬롯: 11:00 / 14:30 / 18:00 (3시간 블록)
- 홀드 기본: 7일
- 대관: 시작~종료 시간 자유 (웨딩 블록과 시간 겹치면 해당 슬롯만 차단)
- 삭제: 기본은 보관(soft delete), 보관함에서 완전 삭제(hard delete) 가능 (MANAGER 이상)

## 구성물
- `schema.sql` : Postgres/Supabase용 DB 스키마 + RLS 정책 + 시드 데이터
- `app/` : Next.js(App Router) 기반 화면 뼈대(대시보드/캘린더/예약/고객/보관함/관리)
- `docs/` : 화면/권한/거래처 스펙 요약

## 빠른 시작(코딩 몰라도 되는 “클릭/복붙” 기준)
1) Supabase에서 새 프로젝트 생성
2) Supabase → SQL Editor에서 `schema.sql` 전체 복붙 후 실행
3) Vercel에서 새 프로젝트 생성(Next.js) 후 이 폴더를 업로드(또는 GitHub 연결)
4) Vercel 환경변수 3개 설정(README 아래)
5) 배포 완료 → 웹사이트 주소로 접속 → 휴대폰 OTP 로그인

## 필요한 환경변수(Vercel/로컬 공통)
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`  (서버 액션/관리 작업용. Vercel에서만 설정 권장)

## 초기 계정/권한
- 대표(ADMIN): 010-9566-3379
- 매니저(MANAGER): 010-5568-8660

> 실제로는 “초대”를 통해 매니저를 등록하는 흐름입니다.  
> `schema.sql`에는 대표 번호를 **최초 ADMIN 부트스트랩**할 수 있도록 트리거가 포함되어 있습니다.

## 주의
- 이 스타터는 “동작 가능한 기본 골격”입니다. 디자인/세부 UX는 운영하면서 조정하면 됩니다.
