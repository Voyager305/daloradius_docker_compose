# daloRADIUS в Docker (nginx + php-fpm + mariadb)

Этот проект поднимает:
- `mariadb` с базой daloRADIUS/FreeRADIUS
- `php-fpm` для выполнения PHP-кода daloRADIUS
- `nginx` с двумя портами:
  - `operators` интерфейс: `http://localhost:8080`
  - `users` интерфейс: `http://localhost:8081`

## Быстрый старт

1. Создай `.env`:
   - `cp .env.example .env`
   - поменяй пароли в `.env`

2. Запусти контейнеры:
   - `docker compose up -d --build`

3. Проверь логи инициализации (первый запуск может занять 1-3 минуты):
   - `docker compose logs -f db-init daloradius-init`

4. Открой интерфейс:
   - operators: `http://localhost:8080`
   - users: `http://localhost:8081`

## Дефолтные данные входа daloRADIUS

После импорта SQL обычно доступны:
- логин: `administrator`
- пароль: `radius`

Рекомендуется сменить пароль сразу после входа.

## Полезные команды

- Перезапуск:
  - `docker compose restart`
- Остановка:
  - `docker compose down`
- Полная пересборка с удалением volumes:
  - `docker compose down -v`
  - `docker compose up -d --build`
