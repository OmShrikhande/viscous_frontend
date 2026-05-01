const istFormatterDate = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Kolkata",
  year: "numeric",
  month: "2-digit",
  day: "2-digit"
});

const istFormatterTime = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Asia/Kolkata",
  hour12: false,
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit"
});

export const getIstDate = (inputDate = new Date()) => {
  return istFormatterDate.format(inputDate);
};

export const getIstTime = (inputDate = new Date()) => {
  return istFormatterTime.format(inputDate).replaceAll(":", "-");
};
