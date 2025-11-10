# dap_tpl - DAP Template Processing System

## Описание

`dap_tpl` - это универсальная система обработки шаблонов. Система поддерживает переменные, условия, циклы, секции AWK и Shell, а также вложенные конструкции.

**Примечание**: Шаблоны конкретного применения (например, для генерации моков DAP SDK) находятся в `test-framework/templates/`, а не внутри `dap_tpl/`, чтобы сохранить универсальность системы.

## Архитектура

Система разделена на модули по принципу Single Responsibility:

### Структура модулей

```
dap_tpl/
├── core/                    # Универсальные базовые функции
│   ├── marker_parser.awk    # Парсинг маркеров {{VAR}} и {{VAR|function|args}}
│   ├── variable_functions.awk  # Обработка функций переменных (split, part, in_list, ne, contains)
│   ├── variable_replacer.awk   # Замена переменных в строках
│   ├── safety_checks.awk      # Проверки безопасности (защита от бесконечных циклов)
│   ├── construct_replacer.awk  # Замена конструкций на обработанный контент
│   └── load_constructs.awk     # Загрузка конструкций из файла
├── constructs/              # Обработка конструкций (#if, #for, #set, #awk)
│   ├── parser_main.awk     # Главный парсер (оркестрация)
│   ├── parser_if.awk       # Парсинг if конструкций
│   ├── parser_for.awk      # Парсинг for конструкций
│   ├── parser_set.awk      # Парсинг set конструкций
│   ├── parser_var.awk      # Парсинг var маркеров
│   ├── parser_awk.awk      # Парсинг awk конструкций
│   ├── parser_include.awk  # Парсинг include конструкций
│   ├── parser_closing.awk  # Парсинг закрывающих тегов
│   ├── stack_manager.awk   # Управление стеком конструкций
│   ├── marker_detector.awk  # Обнаружение маркеров конструкций
│   ├── eval_condition.awk  # Оценка условий (#if)
│   ├── process_loop.awk     # Обработка циклов (#for)
│   ├── set_variable.awk     # Установка переменных (#set)
│   ├── execute_awk_construct.awk  # Выполнение AWK конструкций (#awk)
│   ├── nested_processor.awk      # Рекурсивная обработка вложенных конструкций
│   ├── process_template_constructs.awk  # Главный координатор обработки конструкций
│   └── parse_template_constructs.awk    # Главный парсер конструкций
├── sections/               # Обработка секций ({{AWK:...}}, {{#/bin/sh:...}})
│   ├── extractor.awk      # Извлечение секций (используется extract_sections.awk из utils)
│   ├── executor_awk.awk    # Выполнение AWK секций
│   ├── executor_shell.awk  # Выполнение shell секций
│   ├── multiline_handler.awk  # Обработка многострочных секций
│   ├── replacer.awk        # Замена секций (используется replace_gen_sections.awk из utils)
│   └── process_gen_sections.awk  # Главный координатор обработки секций
├── utils/                  # Утилиты (переиспользуемые функции без состояния)
│   ├── dap_common.awk      # Общие функции
│   ├── extract_sections.awk  # Извлечение секций из шаблона
│   ├── parse_multiline_sections.awk  # Парсинг многострочных секций
│   ├── replace_gen_sections.awk  # Замена секций в шаблоне
│   ├── remove_sections.awk  # Удаление секций из шаблона
│   ├── filter_postproc_sections.awk  # Фильтрация postproc секций
│   ├── replace_template_file.awk  # Замена плейсхолдера содержимым файла
│   ├── replace_template_value.awk  # Замена плейсхолдера значением
│   └── (другие утилиты)
├── tests/                  # Тесты
│   ├── unit/               # Юнит тесты для каждого модуля
│   ├── integration/        # Интеграционные тесты
│   └── fixtures/           # Тестовые шаблоны
├── dap_tpl.sh              # Главный скрипт
└── README.md               # Эта документация
```

## Принципы архитектуры

1. **Fail-fast**: Если ошибка - скрипт падает сразу с понятным сообщением, без fallback'ов
2. **Single Responsibility**: Каждый модуль имеет одну ответственность
3. **Zero Duplication**: Единая точка истины для каждой функции
4. **Модульность**: Модули не зависят друг от друга напрямую (только через интерфейсы)

## Поддерживаемые конструкты языка шаблонов

### Переменные

- `{{VAR}}` - простая переменная
- `{{VAR|split|pipe}}` - разделение переменной по разделителю
- `{{VAR|part|1}}` - получение части после split
- `{{VAR|in_list|LIST}}` - проверка наличия в списке
- `{{VAR|ne|0}}` - сравнение на неравенство
- `{{VAR|contains|substr}}` - проверка подстроки

### Условия

- `{{#if VAR}}...{{/if}}` - простое условие
- `{{#if VAR}}...{{else}}...{{/if}}` - условие с else

### Циклы

- `{{#for item in LIST}}...{{/for}}` - цикл по списку

### Установка переменных

- `{{#set VAR=value}}` - установка переменной

### Секции

- `{{AWK:...}}` - AWK секция
- `{{#/bin/sh:...}}` - Shell секция

## Порядок включения модулей

**ВАЖНО**: Порядок включения модулей критичен для избежания циклических зависимостей.

В `process_template_constructs.awk` модули включаются в следующем порядке:

1. **Core модули** (без зависимостей):
   - `core/variable_functions.awk`
   - `core/variable_replacer.awk`

2. **if_construct.awk** (зависит только от core):
   - `constructs/modules/if_construct.awk`

3. **for_construct.awk** (зависит от core, но НЕ включает nested_constructs):
   - `constructs/modules/for_construct.awk`
   - Использует forward declaration pattern - вызывает `process_nested_constructs()`, но не включает модуль напрямую

4. **nested_constructs.awk** (может использовать if_construct и for_construct):
   - `constructs/modules/nested_constructs.awk`
   - Функции `process_if_construct()` и `process_for_construct()` уже доступны благодаря порядку включения

5. **Другие модули**:
   - `constructs/modules/awk_sections.awk`

**Циклическая зависимость решена через**:
- `for_construct.awk` НЕ включает `nested_constructs.awk` напрямую
- `nested_constructs.awk` НЕ включает `for_construct.awk` напрямую
- Оба модуля включаются в правильном порядке в `process_template_constructs.awk`
- Функции доступны через forward declaration pattern (gawk поддерживает это)

## Использование

```bash
# Установить SCRIPTS_DIR и TEMPLATES_DIR
export SCRIPTS_DIR="/path/to/dap_tpl"
export TEMPLATES_DIR="/path/to/test-framework/templates"  # Шаблоны находятся на уровень выше

# Загрузить функции
source dap_tpl.sh

# Обработать шаблон
replace_template_placeholders template.tpl output.h VAR1=value1 VAR2=value2
```

### Примеры использования конструкций

#### Простые переменные
```tpl
{{BASENAME}}
{{VAR_NAME|split|pipe}}
{{VAR_NAME|part|0}}
```

#### Условия
```tpl
{{#if CUSTOM_MOCKS_LIST}}
#include "custom_mocks.h"
{{/if}}

{{#if VAR}}
Content when true
{{else}}
Content when false
{{/if}}
```

#### Циклы
```tpl
{{#for item in LIST}}
Value: {{item}}
{{/for}}

{{#for outer in OUTER_LIST}}
Outer: {{outer}}
{{#for inner in INNER_LIST}}
  Inner: {{inner}}
{{/for}}
{{/for}}
```

#### Установка переменных
```tpl
{{#set TEMP_VAR=value}}
{{TEMP_VAR}}
```

#### AWK секции
```tpl
{{AWK:
  print "Generated code"
}}
```

## Тестирование

```bash
# Запустить все тесты
cd tests
./run.sh unit
./run.sh integration

# Запустить конкретную группу тестов
cd unit/constructs
./test_constructs.sh

# Запустить конкретный тест
cd unit/core
./test_marker_parser.sh
```

### Покрытие тестами

- **Core модули**: 100% (marker_parser, variable_functions)
- **Constructs**: полное покрытие (if, for, set, var, nested_for, if_with_else, empty_array, deep_nesting, invalid_condition)
- **Sections**: базовая проверка (структура правильная)

## Troubleshooting

### Проблема: "cannot open source file ... for reading"

**Причина**: Неправильный `SCRIPTS_DIR` или `AWKPATH`.

**Решение**:
```bash
export SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
export AWKPATH="${SCRIPTS_DIR}"
```

### Проблема: Циклические зависимости при включении модулей

**Причина**: Неправильный порядок `@include` директив.

**Решение**: Следуйте порядку включения, описанному в разделе "Порядок включения модулей".

### Проблема: Бесконечный цикл при замене переменных

**Причина**: Переменная заменяется на значение, которое само содержит маркер переменной.

**Решение**: Система автоматически обнаруживает такие случаи через `safety_checks.awk` и останавливает замену после 1000 итераций.

### Проблема: Пустой результат для `for` цикла

**Причина**: Массив пуст или содержит только пустые элементы.

**Решение**: Система выводит предупреждение в stderr и возвращает пустую строку. Проверьте значение переменной массива.

### Проблема: Максимальная глубина рекурсии превышена

**Причина**: Слишком глубокая вложенность конструкций (>10 уровней).

**Решение**: Упростите структуру шаблона или увеличьте лимит в `nested_constructs.awk` (не рекомендуется).

## Примеры

См. `tests/integration/` для примеров полной обработки шаблонов.
