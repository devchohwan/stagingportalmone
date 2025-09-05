# Portal Monemusic

모네뮤직 통합 관리 시스템

## 프로젝트 구성

- **Portal (portal.monemusic.com)**: 관리자 대시보드 및 통합 관리
- **Practice (practice.monemusic.com)**: 연습실 예약 시스템
- **Makeup (makeup.monemusic.com)**: 보충수업 예약 시스템

## 기술 스택

- Ruby on Rails 8.0.2
- Ruby 3.4.5
- SQLite3 (개발)
- PostgreSQL (프로덕션 예정)

## 주요 기능

### 공통 기능
- JWT 기반 인증 시스템
- SMS 인증 (Solapi)
- 회원 가입/승인 시스템

### Portal (관리자)
- 회원 관리 (승인/보류/거부)
- 예약 현황 모니터링
- 페널티 관리

### Practice (연습실)
- 연습실 예약/취소
- 예약 현황 조회
- 페널티 시스템 (노쇼/취소)

### Makeup (보충수업)
- 보충수업 예약/취소
- 수업 일정 관리
- 페널티 시스템

## 설치 및 실행

```bash
# 의존성 설치
bundle install

# 데이터베이스 설정
rails db:create
rails db:migrate
rails db:seed

# 환경변수 설정 (.env 파일)
SOLAPI_API_KEY=your_api_key
SOLAPI_API_SECRET=your_api_secret
SOLAPI_SENDER_PHONE=your_phone

# 서버 실행
rails server
```

## 도메인 설정

- Portal: portal.monemusic.com (115.68.195.125)
- Practice: practice.monemusic.com (115.68.195.125)
- Makeup: makeup.monemusic.com (115.68.195.125)

## 라이선스

Private
