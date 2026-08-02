from backend.app import create_app

def main():
	app = create_app()
	# Run local development server
	app.run(host='127.0.0.1', port=5000, debug=True)

if __name__ == '__main__':
	main()
