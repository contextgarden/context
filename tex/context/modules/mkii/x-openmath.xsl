<?xml version="1.0" encoding="utf-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="xml"/>

    <!-- newline, temp hack, latest texexec handles it okay -->

    <xsl:template match="processing-instruction()"><xsl:copy/><xsl:text>
    </xsl:text></xsl:template>

    <!-- xsl:template match="*"><xsl:copy/></xsl:template -->
    <!-- xsl:element name="{name(current())}"><xsl:apply-templates/></xsl:element -->

<!--
    <xsl:template match="*">
        <xsl:copy>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
-->

    <xsl:template match="node()|@*" >
        <xsl:copy>
            <xsl:apply-templates select = "node()|@*" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="comment"></xsl:template>

    <xsl:variable name='openmath-to-content-mathml'><value-of select='$stylesheet-path'/>/x-openmath.xsl</xsl:variable>

    <xsl:include href="x-om2cml.xsl"/>

</xsl:stylesheet>
