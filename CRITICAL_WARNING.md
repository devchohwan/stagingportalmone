# ⚠️ 절대 금지 명령어 ⚠️

## 절대 실행하지 말아야 할 명령어

### 1. db:schema:load
```bash
# 절대 실행 금지!!!
rails db:schema:load
```

**이유**: 
- 데이터베이스를 완전히 초기화함
- 모든 기존 데이터가 삭제됨
- Production 환경에서는 치명적인 데이터 손실 발생

### 2. db:reset, db:drop
```bash
# 절대 실행 금지!!!
rails db:reset
rails db:drop
```

## 올바른 방법

### 컬럼 추가가 필요한 경우:
```bash
# 방법 1: 마이그레이션만 실행
rails db:migrate

# 방법 2: SQL로 직접 추가
rails runner "ActiveRecord::Base.connection.execute('ALTER TABLE table_name ADD COLUMN column_name TYPE')"
```

### 스키마 문제가 있는 경우:
- 절대 schema:load 사용하지 말 것
- 개별 마이그레이션 파일 확인 및 수정
- 필요시 수동으로 ALTER TABLE 실행

## 2025년 9월 10일 사고 기록
- production 환경에서 db:schema:load 실행으로 모든 데이터 초기화됨
- 백업에서 부분 복구 완료
- 교훈: PRODUCTION 환경에서는 데이터 삭제 명령어 절대 금지