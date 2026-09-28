from flask import Flask, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from sqlalchemy import inspect, text

from backend.config import Config

db = SQLAlchemy()
migrate = Migrate()


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Enable CORS for frontend web requests.
    # The Flutter web client sends authenticated JSON requests with
    # Authorization headers, so we must explicitly allow those headers and
    # the methods used by the admin election/candidate flows.
    CORS(
        app,
        resources={r"/*": {"origins": "*"}},
        allow_headers=["Content-Type", "Authorization", "Accept"],
        methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    )

    # Initialize extensions
    db.init_app(app)
    migrate.init_app(app, db)

    # Import all models so SQLAlchemy knows about them
    from backend.models.voter import Voter
    from backend.models.vote import Vote
    from backend.models.election import Election
    from backend.models.candidate import Candidate
    from backend.models.face_log import FaceLog
    from backend.models.security_log import SecurityLog
    from backend.models.audit_log import AuditLog

    # Create any missing tables on startup. The project ships without an
    # applied migration history in some environments, so this keeps the app
    # from failing with 500s when a required table such as `candidates` is
    # absent in the target database.
    with app.app_context():
        db.create_all()
        ensure_voter_schema(app)

    # Register blueprints
    from backend.routes import auth
    app.register_blueprint(auth.bp)

    for module_name in ("voter", "election", "candidate", "vote", "report", "dashboard"):
        try:
            module = __import__(f"backend.routes.{module_name}", fromlist=["bp"])
            app.register_blueprint(module.bp)
        except Exception:
            # Log blueprint registration failures but keep server up
            app.logger.exception("Failed to register blueprint: %s", module_name)

    @app.route('/', methods=['GET'])
    def home():
        return jsonify({
            'message': 'Secure Electronic Voting System backend is running.',
            'info': 'Use /routes to view available API endpoints.',
        })

    @app.route('/routes', methods=['GET'])
    def list_routes():
        rules = []
        for rule in app.url_map.iter_rules():
            rules.append(str(rule))
        return jsonify({'routes': rules})

    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({'status': 'ok'})

    return app


def ensure_voter_schema(app: Flask) -> None:
    """Ensure the voters table includes required migration columns."""
    with app.app_context():
        inspector = inspect(db.engine)
        if not inspector.has_table("voters"):
            return

        columns = {col["name"] for col in inspector.get_columns("voters")}
        if "has_voted" not in columns:
            app.logger.warning("Missing voters.has_voted column detected, adding it now.")
            with db.engine.begin() as conn:
                conn.execute(text("ALTER TABLE voters ADD COLUMN has_voted BOOLEAN DEFAULT FALSE"))
                app.logger.info("Added missing voters.has_voted column.")

