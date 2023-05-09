function scrollRandomly(targetHeight, timeout) {
    const maxScrollStep = 750; // Maximum scroll step size
    const minPauseTime = 100; // Minimum pause time between scrolls in milliseconds
    const maxPauseTime = 2500; // Maximum pause time between scrolls in milliseconds
    const longPauseTime = 3000; // Long pause time between scrolls in milliseconds
    const longPauseChance = 0.075; // Chance to trigger a long pause (0 to 1)
    const reverseScrollChance = 0.05; // Chance to reverse scroll direction (0 to 1)
    const smoothScrollDuration = 250; // Duration of smooth scroll in milliseconds
    let currentHeight = window.innerHeight; // The current height of the viewport
    let scrollTimeoutId; // The ID of the timeout that will be used to wait between each scroll
    let stopTimeoutId; // The ID of the timeout that will be used to stop scrolling after the specified duration

    // Smooth scrolling function
    async function smoothScroll(target) {
        const startTime = performance.now();
        const startY = window.scrollY;
        const distance = target - startY;

        const smoothStep = (timestamp) => {
            const elapsedTime = timestamp - startTime;
            const progress = Math.min(elapsedTime / smoothScrollDuration, 1);
            const scrollY = startY + distance * progress;
            window.scrollTo(0, scrollY);

            if (progress < 1) {
                requestAnimationFrame(smoothStep);
            }
        };

        requestAnimationFrame(smoothStep);
    }

    // Random scrolling function with smoother behavior and reverse scrolling
    function scrollRandomStep() {
        const target = Math.min(currentHeight + maxScrollStep, targetHeight); // The target scroll height
        const distance = target - currentHeight; // The distance to travel to reach the target height
        let step = Math.floor(Math.random() * distance) + 1; // The random size of the scroll step

        // Randomly reverse scroll direction
        if (Math.random() < reverseScrollChance) {
            step = -step;
        }

        currentHeight += step; // Update the current height of the viewport
        smoothScroll(currentHeight); // Smooth scroll to the new position
    }

    // Function to manage pauses between scrolls
    function nextScroll() {
        scrollRandomStep();
        let pauseTime = Math.floor(Math.random() * (maxPauseTime - minPauseTime)) +
        minPauseTime; // Random pause time between scrolls

        // Trigger longer pauses occasionally
        if (Math.random() < longPauseChance) {
            pauseTime = longPauseTime;
        }

        scrollTimeoutId = setTimeout(nextScroll, pauseTime); // Wait randomly between each scroll
    }

    // Function to stop scrolling after the specified timeout
    function stopScrolling() {
        clearTimeout(scrollTimeoutId);
    }

    // Launch the random scrolling
    nextScroll();

    // Stop scrolling after the specified timeout
    if (timeout) {
        stopTimeoutId = setTimeout(stopScrolling, timeout);
    }
}
