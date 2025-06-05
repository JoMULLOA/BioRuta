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
    sender: {
      type: "varchar",
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
