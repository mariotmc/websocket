const exampleSocket = new WebSocket("ws://localhost:2345");

exampleSocket.onopen = function (event) {
  console.log("Connection opened");
  exampleSocket.send("Can you hear me?");
};

exampleSocket.onmessage = function (event) {
  console.log("Received message: " + event.data);
};

exampleSocket.onerror = function (event) {
  console.error("WebSocket error observed:", event);
};

exampleSocket.onclose = function (event) {
  console.log("WebSocket is closed now.");
};

function sendMessage() {
  const input = document.getElementById("message");
  const message = input.value;
  exampleSocket.send(message);
  console.log("Sent message: " + message);
  input.value = ""; // Clear the input field after sending
}
