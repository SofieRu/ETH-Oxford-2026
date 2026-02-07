# from flask import Flask, render_template
# import os

# app = Flask(__name__, static_folder='static')

# @app.route('/')
# def home():
#     return render_template(os.path.join('index.html'))

# @app.route('/Trading')
# def trading():
#     pass

# if __name__ == '__main__':
#     app.run(debug=True)

from flask import Flask, render_template, send_from_directory
import os

from flask import Flask, send_from_directory, render_template
import os

app = Flask(__name__, static_folder='static', template_folder='templates')

# Serve SPA routes
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def catch_all(path):
    return render_template('index.html')

if __name__ == '__main__':
    app.run(debug=True)