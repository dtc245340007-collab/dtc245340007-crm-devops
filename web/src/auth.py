import sys
import logging
from functools import wraps
from flask import session, redirect, url_for, request, abort

# Set up logging strictly to STDERR with exact format requested
auth_logger = logging.getLogger("auth_audit")
auth_logger.setLevel(logging.INFO)
if not auth_logger.handlers:
    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setFormatter(logging.Formatter("%(message)s"))
    auth_logger.addHandler(stderr_handler)
auth_logger.propagate = False

def get_client_ip():
    """Extract client IP respecting X-Forwarded-For."""
    xff = request.headers.get("X-Forwarded-For")
    if xff:
        return xff.split(",")[0].strip()
    return request.remote_addr or "unknown"

def log_login_failure(ip, username, reason):
    """Log failed login strictly in format:
    LOGIN_FAILED ip=<IP> user=<username> reason=<wrong_password|inactive|unknown_user>
    """
    msg = f"LOGIN_FAILED ip={ip} user={username} reason={reason}"
    auth_logger.info(msg)
    sys.stderr.flush()

def log_login_success(ip, username):
    """Log successful login strictly in format:
    LOGIN_SUCCESS ip=<IP> user=<username>
    """
    msg = f"LOGIN_SUCCESS ip={ip} user={username}"
    auth_logger.info(msg)
    sys.stderr.flush()

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login", next=request.full_path))
        return f(*args, **kwargs)
    return decorated_function

def manager_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login", next=request.full_path))
        if session.get("role") != "manager":
            abort(403)
        return f(*args, **kwargs)
    return decorated_function
