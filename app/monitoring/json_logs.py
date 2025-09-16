import structlog
from structlog import get_logger

# Configure Structlog's processor pipeline
structlog.configure(
    processors=[
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", key="ts"),
        structlog.processors.JSONRenderer()
    ],
)
log = get_logger("Structured Logger")
