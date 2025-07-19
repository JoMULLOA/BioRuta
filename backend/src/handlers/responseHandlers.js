"use strict";

export const handleSuccess = (res, statusCode, message, data = null) => {
  const response = {
    success: true,
    message: message
  };
  
  if (data !== null && data !== undefined) {
    response.data = data;
  }
  
  return res.status(statusCode).json(response);
};

export function handleErrorClient(res, statusCode, message, details= {}) {
  return res.status(statusCode).json({
    status: "Client error",
    message,
    details
  });
}

export function handleErrorServer(res, statusCode, message) {
  return res.status(statusCode).json({
    status: "Server error",
    message,
  });
}