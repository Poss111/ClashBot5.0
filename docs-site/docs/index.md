# Clash Companion End User Documentation

<!-- Fancy animation using HTML and CSS only (works in MkDocs Material) -->
<style>
@keyframes gradientBG {
  0% {background-position: 0% 50%;}
  50% {background-position: 100% 50%;}
  100% {background-position: 0% 50%;}
}
.fancy-gradient-banner {
  margin: 2em 0 2em 0;
  width: 100%;
  height: 100px;
  border-radius: 16px;
  font-size: 2em;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: bold;
  letter-spacing: 2px;
  background: linear-gradient(270deg, #FF7F50, #1E90FF, #32CD32, #FFD700, #FF69B4, #1E90FF, #FF7F50);
  background-size: 1400% 1400%;
  animation: gradientBG 12s ease infinite;
  box-shadow: 0 4px 24px 0 rgba(20,60,120,0.13);
  position: relative;
  overflow: hidden;
}
.fancy-gradient-banner::after {
  content: '';
  position: absolute;
  left: 0; top: 0; right: 0; bottom: 0;
  border-radius: 16px;
  pointer-events: none;
  box-shadow: 0 0 60px 10px rgba(255,255,255,0.17) inset;
}
.fancy-shine {
  background: linear-gradient(120deg, rgba(255,255,255,0.18) 20%, rgba(255,255,255,0.13) 60%);
  padding: 0 0.5em;
  border-radius: 6px;
  animation: shine 6s linear infinite;
  display: inline-block;
}
@keyframes shine {
  0% { filter: brightness(1);}
  50% { filter: brightness(1.5);}
  100% { filter: brightness(1);}
}
</style>

<div class="fancy-gradient-banner">
  <span>✨ <span class="fancy-shine">Clash Companion</span> ✨</span>
</div>

Welcome to the end-user documentation for the Clash Companion app. These pages cover:

- What personal data we collect and why.
- How data is stored, shared, and protected.
- How to exercise your privacy choices, including requesting deletion of your data.

If you spot anything that is inaccurate for the current release of the app, please open an issue or contact us via the email listed in the Privacy Policy.


