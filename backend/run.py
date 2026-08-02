from backend.app import create_app, ensure_voter_schema


def main():
	app = create_app()
	ensure_voter_schema(app)
	# Run local development server
	app.run(host='127.0.0.1', port=5000, debug=True)

if __name__ == '__main__':
	main()
