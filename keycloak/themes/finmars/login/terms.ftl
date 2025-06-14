<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=false; section>
    <#if section = "header">
        ${msg("termsTitle")}
    <#elseif section = "form">
        <div id="kc-terms-text">
            ${kcSanitize(msg("termsText"))?no_esc}
        </div>
        <form class="form-actions terms-buttons" action="${url.loginAction}" method="POST">
            <input class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonLargeClass!} pf-m-block" name="accept" id="kc-accept" type="submit" value="${msg("doAccept")}"/>
            <input class="${properties.kcButtonClass!} ${properties.kcButtonDefaultClass!} ${properties.kcButtonLargeClass!} pf-m-block" name="cancel" id="kc-decline" type="submit" value="${msg("doDecline")}"/>
        </form>
        <div class="clearfix"></div>
    </#if>
</@layout.registrationLayout>
