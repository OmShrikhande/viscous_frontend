
function testResetLogic() {
    const istOffset = 5.5 * 60 * 60 * 1000;
    const now = Date.now();
    const istNow = new Date(now + istOffset);
    const istHour = istNow.getUTCHours();
    const istDate = istNow.toISOString().split("T")[0];

    console.log("Current UTC Time:", new Date(now).toISOString());
    console.log("Current IST Time (estimated):", istNow.toISOString());
    console.log("IST Hour:", istHour);
    console.log("IST Date:", istDate);

    const runtimeData = { lastResetDate: "2024-05-13" }; // Yesterday
    
    if (istHour >= 4 && runtimeData.lastResetDate !== istDate) {
        console.log("RESET WOULD TRIGGER");
    } else {
        console.log("RESET WOULD NOT TRIGGER");
    }
}

testResetLogic();
