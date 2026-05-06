/* console.log('✅ Enhanced bootstrap.js loaded.');

document.addEventListener("DOMContentLoaded", function () {
  // 🌸 1. Background & Font
  document.body.style.cssText = `
    background: linear-gradient(rgba(255,255,255,0.7), rgba(255,255,255,0.6)), 
                url('assets/wedding-landing-page-with-photo_52683-24467.avif') no-repeat center center fixed;
    background-size: cover;
    font-family: 'Playfair Display', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    margin: 0;
    padding-top: 80px;
  `;

  // 🌟 2. Observer for Flutter Elements
  const observer = new MutationObserver(() => {
    // 🎀 Card Containers
    document.querySelectorAll('.card, .container, .form-group, .scaffold, .box').forEach(box => {
      Object.assign(box.style, {
        boxShadow: "0 16px 40px rgba(0, 0, 0, 0.2)",
        borderRadius: "24px",
        background: "rgba(255, 255, 255, 0.95)",
        backdropFilter: "blur(14px)",
        padding: "32px",
        margin: "36px auto",
        maxWidth: "520px",
        border: "1px solid rgba(200,200,200,0.3)",
        transform: "scale(1)",
        transition: "transform 0.3s ease-in-out"
      });
      box.onmouseenter = () => (box.style.transform = "scale(1.02)");
      box.onmouseleave = () => (box.style.transform = "scale(1)");
    });

    // 🎨 Inputs
    document.querySelectorAll("input[type=text], input[type=email], input[type=password], input[type=tel], textarea").forEach(input => {
      Object.assign(input.style, {
        borderRadius: "14px",
        padding: "14px 20px",
        marginBottom: "20px",
        border: "1px solid #d4d4d4",
        backgroundColor: "#fff",
        fontSize: "17px",
        boxShadow: "0 2px 6px rgba(0,0,0,0.04)",
        width: "100%",
        outline: "none",
        transition: "border 0.3s ease"
      });
      input.onfocus = () => input.style.borderColor = "#e91e63";
      input.onblur = () => input.style.borderColor = "#d4d4d4";
    });

    // 🏷 Labels
    document.querySelectorAll("label").forEach(label => {
      Object.assign(label.style, {
        fontWeight: "600",
        fontSize: "15px",
        color: "#444",
        marginBottom: "8px",
        display: "inline-block"
      });
    });

    // 🔘 Buttons
    document.querySelectorAll("button, .btn, input[type=submit]").forEach(btn => {
      Object.assign(btn.style, {
        borderRadius: "14px",
        padding: "14px 20px",
        backgroundColor: "#e91e63",
        color: "#fff",
        fontWeight: "600",
        fontSize: "17px",
        border: "none",
        cursor: "pointer",
        width: "100%",
        marginTop: "16px",
        boxShadow: "0 4px 16px rgba(233, 30, 99, 0.3)",
        transition: "all 0.3s ease"
      });
      btn.onmouseenter = () => btn.style.backgroundColor = "#c2185b";
      btn.onmouseleave = () => btn.style.backgroundColor = "#e91e63";
    });

    // 📝 Titles
    document.querySelectorAll("h1, h2, h3, .title").forEach(h => {
      Object.assign(h.style, {
        color: "#2c003e",
        fontWeight: "800",
        fontSize: "30px",
        textAlign: "center",
        marginBottom: "24px",
        fontFamily: "'Playfair Display', serif"
      });
    });

    // 🔗 Toggle Links
    document.querySelectorAll("a, .toggle-text, .link, button.toggle-btn").forEach(link => {
      Object.assign(link.style, {
        color: "#9c27b0",
        fontSize: "15px",
        fontWeight: "600",
        textDecoration: "underline",
        marginTop: "12px",
        display: "inline-block",
        textAlign: "center",
      });
    });

    // 🍩 Snackbar
    document.querySelectorAll(".snackbar, .alert").forEach(snack => {
      Object.assign(snack.style, {
        borderRadius: "8px",
        padding: "12px 18px",
        margin: "12px 0",
        fontWeight: "600",
        fontSize: "15px",
        boxShadow: "0 6px 20px rgba(0,0,0,0.1)",
      });
    });

    // 📃 List Items
    document.querySelectorAll("li, .list-group-item").forEach(item => {
      Object.assign(item.style, {
        padding: "12px 18px",
        borderBottom: "1px solid #eee",
        borderRadius: "10px",
        backgroundColor: "rgba(255,255,255,0.9)",
        marginBottom: "8px"
      });
    });
  });

  observer.observe(document.body, { childList: true, subtree: true });
});
*/