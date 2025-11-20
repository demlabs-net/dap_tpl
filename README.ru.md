# Система обработки шаблонов DAP (dap_tpl)

Система обработки шаблонов для test framework DAP SDK с модульной архитектурой и расширяемым дизайном.

**Языки:** [English](README.md) | [Русский](README.ru.md)

## Возможности

- Модульная система на основе плагинов
- Расширенный парсинг условий с логическими операторами
- Система макросов с параметрами
- Рекурсивное включение шаблонов
- Функции преобразования переменных
- Встроенное выполнение AWK и shell скриптов

## Быстрый старт

### Базовое использование

```bash
# Подключить библиотеку
source dap_tpl/dap_tpl.sh

# Обработать шаблон
replace_template_placeholders \
    "input.tpl" \
    "output.h" \
    "VAR1=value1" \
    "VAR2=value2"

# С расширениями для мокинга
replace_template_placeholders \
    "input.tpl" \
    "output.h" \
    --extensions-dir "../mocks/lib/dap_tpl" \
    "TYPE=dap_list_t*"
```

### Синтаксис шаблонов

```
{{VAR}}                                  - Подстановка переменной
{{VAR|split|pipe}}                       - Переменная с функцией
{{#if VAR}}...{{else}}...{{/if}}        - Условие
{{#if VAR == value}}...{{/if}}          - Сравнение
{{#if VAR > 5}}...{{/if}}               - Числовое сравнение
{{#if VAR contains 'text'}}...{{/if}}   - Проверка подстроки
{{#if VAR1 && VAR2}}...{{/if}}          - Логическое И
{{#if VAR1 || VAR2}}...{{/if}}          - Логическое ИЛИ
{{#if !VAR}}...{{/if}}                  - Логическое НЕ
{{#elif VAR == 2}}...{{/elif}}          - Иначе-если
{{#for item in LIST}}...{{/for}}        - Цикл
{{#set VAR=value}}...{{/set}}           - Присваивание переменной
{{#macro NAME}}...{{/macro}}            - Определение макроса
{{#call NAME|arg1|arg2}}                - Вызов макроса
{{#include "file.tpl"}}                 - Включение шаблона
{{! комментарий }}                      - Однострочный комментарий
{{!-- многострочный комментарий --}}    - Многострочный комментарий
```

## Архитектура

### Базовые модули

- **token_tree.awk** - Управление AST
- **variable_context.awk** - Стековая область видимости переменных
- **macro_store.awk** - Хранение и раскрытие макросов
- **construct_registry.awk** - Система регистрации плагинов
- **tokenizer_core.awk** - Универсальный токенизатор с диспетчеризацией
- **evaluator_core.awk** - Универсальный вычислитель с диспетчеризацией
- **renderer.awk** - Преобразование AST в текст
- **condition_parser.awk** - Парсинг условий

### Конструкции

Каждая конструкция — это самостоятельный плагин:
- **if** - Условные блоки с elif/else
- **for** - Итерация по циклу
- **set** - Присваивание переменных
- **var** - Подстановка переменных
- **macro** - Переиспользуемые фрагменты
- **call** - Вызов макроса
- **include** - Включение шаблонов
- **comment** - Комментарии
- **awk_section** - Выполнение AWK кода
- **sh_section** - Выполнение shell скриптов

## Сборка

```bash
# Собрать движок
./utils/build_engine.sh

# Собрать с расширениями
./utils/build_engine.sh ../mocks/lib/dap_tpl

# Получить путь к движку
ENGINE_OUTPUT=$(./utils/build_engine.sh 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
```

## Тестирование

Все тесты находятся в директории `dap-sdk/tests/` и могут быть запущены через:

```bash
# Из директории dap-sdk/tests/
cd ../../tests
./run.sh                    # Все тесты (C тесты + test-framework тесты)
./run.sh unit               # Только unit тесты
./run.sh integration        # Только integration тесты
./run.sh test-framework     # Только test-framework тесты (AWK/shell)
./run.sh c-tests            # Только C тесты (через ctest)
```

**Через CTest (рекомендуется):**
```bash
cd dap-sdk/build
ctest -L test-framework --output-on-failure
```

**Структура тестов:**
- `tests/unit/test-framework/` - Unit тесты для dap_tpl core
- `tests/integration/test-framework/` - Integration тесты для полного пайплайна
- `tests/unit/test-framework/c/` - C тесты для mock framework

Результаты тестов: 41+ тестов (27 unit + 10 integration + 4 mocking)

## Документация

- **[docs/DAP_TPL_GUIDE.ru.md](docs/DAP_TPL_GUIDE.ru.md)** - Полное руководство с туториалом, справочником и cookbook
- **[docs/examples/](docs/examples/)** - 7 примеров шаблонов с путём обучения

## Функции переменных

Базовые функции:
- `split` - Разделить значение: `{{VAR|split|pipe}}`
- `part` - Получить часть: `{{VAR|part|0}}`
- `contains` - Проверить подстроку: `{{VAR|contains|text}}`
- `ne` - Не равно: `{{VAR|ne|value}}`
- `in_list` - Проверить в списке: `{{VAR|in_list}}`
- `replace` - Заменить паттерн: `{{VAR|replace|pattern|replacement}}`
- `remove_suffix` - Удалить суффикс: `{{VAR|remove_suffix|_t}}`
- `trim` - Убрать пробелы: `{{VAR|trim}}`

## Добавление новых конструкций

1. Создать директорию конструкции: `constructs/my_construct/`
2. Добавить необходимые файлы:
   - `definition.awk` - Регистрация конструкции в реестре
   - `tokenizer.awk` - Парсинг синтаксиса конструкции
   - `evaluator.awk` - Логика вычисления конструкции
3. Пересобрать движок: `./utils/build_engine.sh`

Система сборки автоматически обнаруживает и включает новые конструкции.

См. [docs/DAP_TPL_GUIDE.ru.md](docs/DAP_TPL_GUIDE.ru.md#добавление-новых-конструкций) для подробного руководства.

## Требования

- GNU AWK 4.0+
- Bash 3.0+
- GNU coreutils

## Лицензия

Часть DAP SDK - Cellframe Network

