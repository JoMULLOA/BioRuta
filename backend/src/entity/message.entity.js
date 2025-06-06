"use strict";
import { EntitySchema } from "typeorm";

const MessageSchema = new EntitySchema({
  name: "Message",
  tableName: "messages",
  columns: {
    id: {
      type: "int",
      primary: true,
      generated: true,
    },
    senderId: {
      type: "int",
      nullable: false,
    },
    receiverId: {
      type: "int",
      nullable: false,
    },
    text: {
      type: "text",
      nullable: false,
    },
    createdAt: {
      type: "timestamp",
      createDate: true,
    },
  },
});

export default MessageSchema;
