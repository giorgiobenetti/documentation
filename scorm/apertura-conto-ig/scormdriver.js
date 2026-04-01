/* SCORM 1.2 minimal runtime for LearnWorlds-compatible packages */
(function () {
  "use strict";

  var OPEN_ACCOUNT_URL =
    "https://www.ig.com/it/application-form?QPID=3774844611&QPPID=1";
  var SCORM = {
    api: null,
    initialized: false,
  };

  function findScormApi(win) {
    var maxTries = 12;
    var current = win;
    while (current && maxTries > 0) {
      try {
        if (current.API) {
          return current.API;
        }
      } catch (err) {
        return null;
      }
      current = current.parent;
      maxTries -= 1;
    }
    return null;
  }

  function initializeScorm() {
    SCORM.api = findScormApi(window);
    if (!SCORM.api) {
      return;
    }
    var initResult = SCORM.api.LMSInitialize("");
    SCORM.initialized = initResult === "true";
    if (!SCORM.initialized) {
      return;
    }
    SCORM.api.LMSSetValue("cmi.core.lesson_status", "incomplete");
    SCORM.api.LMSSetValue("cmi.core.score.min", "0");
    SCORM.api.LMSSetValue("cmi.core.score.max", "100");
    SCORM.api.LMSCommit("");
  }

  function completeLesson() {
    if (!SCORM.initialized || !SCORM.api) {
      return false;
    }
    SCORM.api.LMSSetValue("cmi.core.lesson_status", "completed");
    SCORM.api.LMSSetValue("cmi.core.score.raw", "100");
    SCORM.api.LMSCommit("");
    return true;
  }

  function terminateScorm() {
    if (SCORM.initialized && SCORM.api) {
      SCORM.api.LMSCommit("");
      SCORM.api.LMSFinish("");
    }
  }

  function setStatus(message, isError) {
    var el = document.getElementById("status-message");
    if (!el) {
      return;
    }
    el.textContent = message;
    el.style.color = isError ? "#c1121f" : "#0ea75e";
  }

  function bindUi() {
    var openButton = document.getElementById("cta-open-account");
    var completeButton = document.getElementById("cta-complete");
    if (!openButton || !completeButton) {
      return;
    }

    openButton.addEventListener("click", function () {
      window.open(OPEN_ACCOUNT_URL, "_blank", "noopener,noreferrer");
      setStatus("Link aperto in una nuova scheda. Completa il form IG.", false);
    });

    completeButton.addEventListener("click", function () {
      var tracked = completeLesson();
      if (tracked) {
        setStatus("Completamento registrato su LearnWorlds.", false);
      } else {
        setStatus(
          "Procedura completata (tracking SCORM non disponibile in anteprima).",
          false
        );
      }
    });
  }

  window.addEventListener("load", function () {
    initializeScorm();
    bindUi();
  });

  window.addEventListener("beforeunload", function () {
    terminateScorm();
  });
})();
