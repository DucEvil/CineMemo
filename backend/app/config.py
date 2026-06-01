import os
from typing import List


def get_env(name: str, default: str = "") -> str:
    return os.getenv(name, default)


def get_cors_origins() -> List[str]:
    raw = get_env("CORS_ORIGINS", "")
    return [item.strip() for item in raw.split(",") if item.strip()]


def get_database_url() -> str:
    user = get_env("DB_USER", "")
    password = get_env("DB_PASS", "")
    db_name = get_env("DB_NAME", "")
    host = get_env("DB_HOST", "127.0.0.1")
    port = get_env("DB_PORT", "3306")

    socket_dir = get_env("DB_SOCKET_DIR", "")
    instance = get_env("DB_INSTANCE_CONNECTION_NAME", "")

    if socket_dir and instance:
        socket_path = f"{socket_dir}/{instance}"
        return (
            "mysql+pymysql://{user}:{password}@/{db_name}?unix_socket={socket}"
        ).format(user=user, password=password, db_name=db_name, socket=socket_path)

    return (
        "mysql+pymysql://{user}:{password}@{host}:{port}/{db_name}"
    ).format(user=user, password=password, host=host, port=port, db_name=db_name)


def get_firebase_project_id() -> str:
    return get_env("FIREBASE_PROJECT_ID", "")


def get_firebase_service_account_path() -> str:
    return get_env("FIREBASE_SERVICE_ACCOUNT", "")
