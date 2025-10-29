#!/bin/bash

#===============================================================================
# Универсальный скрипт миграции сайтов v5.0
# Режимы: 1) Копирование на том же сервере
#         2) Перенос на другой сервер
#         3) Массовый перенос всех сайтов
# Поддержка: FastPanel, HestiaCP, ISPManager, VestaCP, cPanel, DirectAdmin, Plesk
#===============================================================================

set -e
trap 'error_handler $? $LINENO' ERR

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Глобальные переменные
LOG_FILE="/var/log/site_migration_$(date +%Y%m%d_%H%M%S).log"
TEMP_DUMP_FILE=""
CONTROL_PANEL=""
ROLLBACK_STACK=()
MIGRATION_STATE_FILE="/tmp/migration_state_$(date +%Y%m%d_%H%M%S).json"
MIGRATION_MODE=""

# Состояние миграции
declare -A MIGRATION_STATE=(
    [stage]="init"
    [mode]=""
    [source_site]=""
    [target_site]=""
    [target_host]=""
    [target_user]=""
    [target_ip]=""
    [target_path]=""
    [db_created]=false
    [db_name]=""
    [db_user]=""
    [site_created]=false
    [files_copied]=false
    [backup_created]=false
    [backup_path]=""
    [ssl_installed]=false
)

#===============================================================================
# СИСТЕМА ЛОГИРОВАНИЯ
#===============================================================================

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $message" >> "$LOG_FILE"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $message" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $message" >> "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE"
}

#===============================================================================
# СИСТЕМА ОТКАТА
#===============================================================================

save_migration_state() {
    local state_json="{"
    for key in "${!MIGRATION_STATE[@]}"; do
        state_json+="\"$key\":\"${MIGRATION_STATE[$key]}\","
    done
    state_json="${state_json%,}}"
    echo "$state_json" > "$MIGRATION_STATE_FILE"
}

error_handler() {
    local exit_code=$1
    local line_number=$2
    
    log_error "Ошибка на линии $line_number (код: $exit_code)"
    log_error "Запускаю автоматический откат..."
    
    perform_rollback
    exit "$exit_code"
}

add_rollback_action() {
    local action="$1"
    ROLLBACK_STACK+=("$action")
    log_info "Добавлено действие отката: $action"
}

perform_rollback() {
    log_warning "╔════════════════════════════════════════════════════════════╗"
    log_warning "║ АВТОМАТИЧЕСКИЙ ОТКАТ ИЗМЕНЕНИЙ                            ║"
    log_warning "╚════════════════════════════════════════════════════════════╝"
    
    local stack_length=${#ROLLBACK_STACK[@]}
    
    if [[ $stack_length -eq 0 ]]; then
        log_info "Нет действий для отката"
        return 0
    fi
    
    for ((i=stack_length-1; i>=0; i--)); do
        local action="${ROLLBACK_STACK[$i]}"
        log_info "Откат: $action"
        
        case "$action" in
            "remove_temp_dump")
                [[ -n "$TEMP_DUMP_FILE" ]] && [[ -f "$TEMP_DUMP_FILE" ]] && rm -f "$TEMP_DUMP_FILE"
                ;;
            "remove_database")
                if [[ "${MIGRATION_STATE[db_created]}" == "true" ]]; then
                    mysql -e "DROP DATABASE IF EXISTS \`${MIGRATION_STATE[db_name]}\`;" 2>/dev/null || true
                    mysql -e "DROP USER IF EXISTS '${MIGRATION_STATE[db_user]}'@'localhost';" 2>/dev/null || true
                    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
                    log_success "БД ${MIGRATION_STATE[db_name]} удалена"
                fi
                ;;
            "remove_site")
                if [[ "${MIGRATION_STATE[site_created]}" == "true" ]]; then
                    local site="${MIGRATION_STATE[target_site]}"
                    local user="${MIGRATION_STATE[target_user]}"
                    
                    case $CONTROL_PANEL in
                        "hestia")
                            v-delete-web-domain "$user" "$site" 2>/dev/null || true
                            ;;
                        "fastpanel")
                            mogwai sites delete --server-name="$site" 2>/dev/null || true
                            ;;
                        "ispmanager")
                            /usr/local/mgr5/sbin/mgrctl -m ispmgr webdomain.delete elid="$site" 2>/dev/null || true
                            ;;
                    esac
                    log_success "Сайт $site удален"
                fi
                ;;
            "remove_user_fastpanel")
                if [[ "$CONTROL_PANEL" == "fastpanel" ]] && [[ -n "${MIGRATION_STATE[target_user]}" ]]; then
                    mogwai users delete --username="${MIGRATION_STATE[target_user]}" 2>/dev/null || true
                    log_success "Пользователь ${MIGRATION_STATE[target_user]} удален"
                fi
                ;;
            "restore_files")
                if [[ "${MIGRATION_STATE[files_copied]}" == "true" ]] && [[ -d "${MIGRATION_STATE[target_path]}" ]]; then
                    rm -rf "${MIGRATION_STATE[target_path]:?}"/* 2>/dev/null || true
                    log_success "Файлы очищены"
                fi
                ;;
            "remove_backup")
                if [[ "${MIGRATION_STATE[backup_created]}" == "true" ]] && [[ -d "${MIGRATION_STATE[backup_path]}" ]]; then
                    rm -rf "${MIGRATION_STATE[backup_path]}" 2>/dev/null || true
                    log_success "Бекап удален"
                fi
                ;;
        esac
    done
    
    cleanup_migration_state
    log_success "Откат завершен"
}

cleanup_migration_state() {
    [[ -f "$MIGRATION_STATE_FILE" ]] && rm -f "$MIGRATION_STATE_FILE"
    rm -f /tmp/fastpanel_site_user.info
    rm -f /tmp/hestia_actual_db_name.info
    rm -f /tmp/*_error.log 2>/dev/null || true
}

#===============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
#===============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться от root"
        exit 1
    fi
}

check_mysql_connection() {
    log_info "Проверяю MySQL..."
    if ! mysql -e "SELECT 1;" &>/dev/null; then
        log_error "MySQL недоступен!"
        exit 1
    fi
    log_success "MySQL доступен"
}

generate_random_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n1
}

choose_admin_email() {
    local domain="$1"
    local tld="${domain##*.}"
    local invalid_tlds=("local" "copy" "test" "localhost" "lan" "isp" "hestia")
    
    for bad in "${invalid_tlds[@]}"; do
        if [[ "$tld" == "$bad" ]]; then
            echo "admin@example.com"
            return 0
        fi
    done
    
    if [[ "$domain" != *.* ]]; then
        echo "admin@example.com"
        return 0
    fi
    
    echo "admin@$domain"
}

#===============================================================================
# ОПРЕДЕЛЕНИЕ ПАНЕЛЕЙ УПРАВЛЕНИЯ
#===============================================================================

detect_local_panel() {
    log_info "Определяю панель управления..."
    
    if [[ -d "/usr/local/fastpanel" ]] || systemctl is-active --quiet fastpanel2.service 2>/dev/null; then
        echo "fastpanel"
        return
    fi
    
    if [[ -d "/usr/local/hestia" ]] || systemctl is-active --quiet hestia.service 2>/dev/null; then
        echo "hestia"
        return
    fi
    
    if [[ -d "/usr/local/vesta" ]]; then
        echo "vesta"
        return
    fi
    
    if [[ -d "/usr/local/cpanel" ]]; then
        echo "cpanel"
        return
    fi
    
    if [[ -d "/usr/local/ispmgr" ]] || systemctl is-active --quiet ihttpd.service 2>/dev/null; then
        echo "ispmanager"
        return
    fi
    
    if [[ -d "/usr/local/directadmin" ]]; then
        echo "directadmin"
        return
    fi
    
    if [[ -d "/usr/local/psa" ]]; then
        echo "plesk"
        return
    fi
    
    echo "unknown"
}

detect_remote_panel() {
    local host=$1
    local ssh_port=${2:-22}
    
    log_info "Определяю панель на $host..."
    
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$ssh_port" root@"$host" "exit" 2>/dev/null; then
        log_error "Не удается подключиться к $host"
        return 1
    fi
    
    if ssh -p "$ssh_port" root@"$host" "[ -d /usr/local/fastpanel ]" 2>/dev/null; then
        echo "fastpanel"
    elif ssh -p "$ssh_port" root@"$host" "[ -d /usr/local/hestia ]" 2>/dev/null; then
        echo "hestia"
    elif ssh -p "$ssh_port" root@"$host" "[ -d /usr/local/vesta ]" 2>/dev/null; then
        echo "vesta"
    elif ssh -p "$ssh_port" root@"$host" "[ -d /usr/local/cpanel ]" 2>/dev/null; then
        echo "cpanel"
    elif ssh -p "$ssh_port" root@"$host" "[ -d /usr/local/ispmgr ]" 2>/dev/null; then
        echo "ispmanager"
    elif ssh -p "$ssh_port" root@"$host" "[ -d /usr/local/directadmin ]" 2>/dev/null; then
        echo "directadmin"
    elif ssh -p "$ssh_port" root@"$host" "[ -d /usr/local/psa ]" 2>/dev/null; then
        echo "plesk"
    else
        echo "unknown"
    fi
}

# [ОСТАЛЬНЫЕ ФУНКЦИИ ОСТАЮТСЯ БЕЗ ИЗМЕНЕНИЙ - detect_cms, find_site_directory, get_site_owner, 
#  get_all_sites, get_db_info_from_wp_config, get_db_info_from_dle_config, 
#  create_local_backup, create_site, create_database, update_wp_config, 
#  update_dle_config, update_wp_urls_in_db, mode_local_copy, mode_remote_transfer, 
#  mode_bulk_transfer - ИЗ ПРЕДЫДУЩЕЙ ВЕРСИИ]

#===============================================================================
# ГЛАВНОЕ МЕНЮ
#===============================================================================

show_menu() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║      🚀 Универсальный скрипт миграции сайтов v5.0 🚀      ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Выберите режим работы:"
    echo ""
    echo "  1) Копирование сайта на том же сервере"
    echo "     └─ Создает копию сайта с новым доменом и БД"
    echo ""
    echo "  2) Перенос сайта на другой сервер"
    echo "     └─ Переносит один сайт на удаленный сервер"
    echo ""
    echo "  3) Массовый перенос всех сайтов"
    echo "     └─ Переносит все сайты на удаленный сервер"
    echo ""
    echo "  0) Выход"
    echo ""
    read -p "Ваш выбор (0-3): " choice
    
    case $choice in
        1)
            mode_local_copy
            ;;
        2)
            mode_remote_transfer
            ;;
        3)
            mode_bulk_transfer
            ;;
        0)
            log_info "Выход из программы"
            exit 0
            ;;
        *)
            log_error "Неверный выбор"
            sleep 2
            show_menu
            ;;
    esac
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    check_root
    check_mysql_connection
    
    CONTROL_PANEL=$(detect_local_panel)
    
    if [[ "$CONTROL_PANEL" == "unknown" ]]; then
        log_error "Не удалось определить панель управления"
        exit 1
    fi
    
    log_info "Панель управления: $CONTROL_PANEL"
    log_info "Лог-файл: $LOG_FILE"
    
    show_menu
}

main "$@"
