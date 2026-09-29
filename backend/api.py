from flask import Flask, jsonify, request, Response, stream_with_context

app = Flask(__name__)

@app.route('/api/ask', methods=['POST'])
def agent_endpoint():
    data = request.get_json()
    user_query = data.get('question', "return none")

    from orchestrator import run_agent
    
    def generate():
        for chunk in run_agent(user_query):
            yield chunk

    return Response(stream_with_context(generate()), mimetype='text/plain')