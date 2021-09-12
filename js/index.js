document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll(".article-summary").forEach((e) =>
    e.addEventListener("click", function () {
      window.location.href = e.querySelector("header h2 a").href;
    })
  );
});
