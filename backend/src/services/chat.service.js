const Message = require('../entity/message.entity');

const saveMessage = async (data) => {
  return await Message.create({
    sender: data.sender,
    text: data.message,
  });
};

const getMessages = async () => {
  return await Message.findAll({
    order: [['createdAt', 'DESC']],
    limit: 50,
  });
};

module.exports = {
  saveMessage,
  getMessages,
};
