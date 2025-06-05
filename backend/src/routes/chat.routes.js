const express = require("express");
const router = express.Router();
const chatService = require("../services/chatService");

router.get("/messages", async (req, res) => {
  const messages = await chatService.getMessages();
  res.json(messages);
});

module.exports = router;
