<?xml version="1.0" encoding="utf-8"?>

<!--
    This style sheet is used in the Math4All project. This project
    will provide an on-line math method for secondary and tertiary
    education. In addition to the web-bases content the project
    provides high quality typeset output as well.

    This style converts some elements to open math alternatives and
    its sole purpose is to easy the input of inline math.

    <i>x</i>    identifier (use <v>x</v> when possible)
    <n>5</n>    number
    <v>5</v>    variable
    <r>1:2</r>  interval (range)
    <r>x:y</r>  interval (range) using variables

    This style is dedicated to Frits Spijkers, an open minded math
    author who patiently tested all the related TeX things.

    Hans Hagen, PRAGMA ADE, Hasselt NL / 2006-04-27

-->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="xml"/>

    <xsl:template match="processing-instruction()"><xsl:copy/><xsl:text>
    </xsl:text></xsl:template>

    <xsl:template match="node()|@*" >
        <xsl:copy>
            <xsl:apply-templates select = "node()|@*" />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="comment"></xsl:template>

    <xsl:variable name='openmath-to-content-mathml'><value-of select='$stylesheet-path'/>/x-openmath.xsl</xsl:variable>

    <xsl:template name='om-minus'>
        <OMS cd="arith1" name="unary_minus"/>
    </xsl:template>
    <xsl:template name='om-infinity'>
        <OMS cd="nums1" name="infinity"/>
    </xsl:template>
    <xsl:template name='om-interval-oo'>
        <OMS cd="interval1" name="interval_oo"/>
    </xsl:template>
    <xsl:template name='om-interval-oc'>
        <OMS cd="interval1" name="interval_oc"/>
    </xsl:template>
    <xsl:template name='om-interval-co'>
        <OMS cd="interval1" name="interval_co"/>
    </xsl:template>
    <xsl:template name='om-interval-cc'>
        <OMS cd="interval1" name="interval_cc"/>
    </xsl:template>

    <xsl:template name='om-kind-of-data'>
        <xsl:param name='arg'/>
        <xsl:choose>
            <xsl:when test="contains($arg,'/')">
                <xsl:element name="OMA">
                    <xsl:element name="OMS">
                        <xsl:attribute name="cd">nums1</xsl:attribute>
                        <xsl:attribute name="name">rational</xsl:attribute>
                    </xsl:element>
                    <xsl:call-template name="om-kind-of-data">
                        <xsl:with-param name='arg' select="substring-before($arg,'/')"/>
                    </xsl:call-template>
                    <xsl:call-template name="om-kind-of-data">
                        <xsl:with-param name='arg' select="substring-after($arg,'/')"/>
                    </xsl:call-template>
                </xsl:element>
            </xsl:when>
            <xsl:when test="contains($arg,'.') or contains($arg,',')">
                <xsl:element name="OMF">
                    <xsl:attribute name="dec"><xsl:value-of select="$arg"/></xsl:attribute>
                </xsl:element>
            </xsl:when>
            <xsl:when test="number($arg)">
                <xsl:choose>
                    <xsl:when test="contains($arg,'-')">
                        <xsl:element name="OMA">
                            <xsl:call-template name='om-minus'/>
                            <xsl:element name="OMI">
                                <xsl:value-of select="substring-after($arg,'-')"/>
                            </xsl:element>
                        </xsl:element>
                    </xsl:when>
                    <xsl:when test="contains($arg,'+')">
                        <xsl:element name="OMI">
                            <xsl:value-of select="substring-after($arg,'+')"/>
                        </xsl:element>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:element name="OMI">
                            <xsl:value-of select="$arg"/>
                        </xsl:element>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="OMV">
                    <xsl:attribute name="name"><xsl:value-of select="$arg"/></xsl:attribute>
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match='i|n'>
        <xsl:element name="OMOBJ">
            <xsl:attribute name="style">inline</xsl:attribute>
            <xsl:attribute name="xmlns">http://www.openmath.org/OpenMath</xsl:attribute>
            <xsl:attribute name="version">2.0</xsl:attribute>
            <xsl:call-template name="om-kind-of-data">
                <xsl:with-param name='arg' select="text()"/>
            </xsl:call-template>
        </xsl:element>
    </xsl:template>

    <xsl:template match='v'>
        <xsl:element name="OMOBJ">
            <xsl:attribute name="style">inline</xsl:attribute>
            <xsl:attribute name="xmlns">http://www.openmath.org/OpenMath</xsl:attribute>
            <xsl:attribute name="version">2.0</xsl:attribute>
            <xsl:element name="OMV">
                <xsl:attribute name="name"><xsl:apply-templates/></xsl:attribute>
            </xsl:element>
        </xsl:element>
    </xsl:template>

    <!-- r a/b split in two parts -->

    <xsl:template match='r'>
        <xsl:element name="OMOBJ">
            <xsl:attribute name="style">inline</xsl:attribute>
            <xsl:attribute name="xmlns">http://www.openmath.org/OpenMath</xsl:attribute>
            <xsl:attribute name="version">2.0</xsl:attribute>
            <xsl:element name="OMA">
                <xsl:variable name='type'>
                    <xsl:choose>
                        <xsl:when test="@type=''">
                            cc
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@type"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="@type='io'">
                        <xsl:call-template name='om-interval-oo'/>
                        <xsl:element name="OMA">
                            <xsl:call-template name='om-minus'/>
                            <xsl:call-template name='om-infinity'/>
                        </xsl:element>
                        <xsl:element name="OMI">
                            <xsl:call-template name='om-kind-of-data'>
                                <xsl:with-param name='arg' select='text()'/>
                            </xsl:call-template>
                        </xsl:element>
                    </xsl:when>
                    <xsl:when test="@type='oi'">
                        <xsl:call-template name='om-interval-oo'/>
                        <xsl:element name="OMI">
                            <xsl:call-template name='om-kind-of-data'>
                                <xsl:with-param name='arg' select='text()'/>
                            </xsl:call-template>
                        </xsl:element>
                        <xsl:call-template name='om-infinity'/>
                    </xsl:when>
                    <xsl:when test="@type='ic'">
                        <xsl:call-template name='om-interval-oc'/>
                        <xsl:element name="OMA">
                            <xsl:call-template name='om-minus'/>
                            <xsl:call-template name='om-infinity'/>
                        </xsl:element>
                        <xsl:element name="OMI">
                            <xsl:call-template name='om-kind-of-data'>
                                <xsl:with-param name='arg' select='text()'/>
                            </xsl:call-template>
                        </xsl:element>
                    </xsl:when>
                    <xsl:when test="@type='ci'">
                        <xsl:call-template name='om-interval-co'/>
                        <xsl:element name="OMI">
                            <xsl:call-template name='om-kind-of-data'>
                                <xsl:with-param name='arg' select='text()'/>
                            </xsl:call-template>
                        </xsl:element>
                        <xsl:call-template name='om-infinity'/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:element name="OMS">
                            <xsl:attribute name="cd">interval1</xsl:attribute>
                            <xsl:attribute name="name">interval_<xsl:value-of select="$type"/></xsl:attribute>
                        </xsl:element>
                        <xsl:call-template name="om-kind-of-data">
                            <xsl:with-param name='arg' select="substring-before(text(),':')"/>
                        </xsl:call-template>
                        <xsl:call-template name="om-kind-of-data">
                            <xsl:with-param name='arg' select="substring-after(text(),':')"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:element>
        </xsl:element>
    </xsl:template>

    <xsl:template match='c'>
        <xsl:element name="OMOBJ">
            <xsl:attribute name="style">inline</xsl:attribute>
            <xsl:attribute name="xmlns">http://www.openmath.org/OpenMath</xsl:attribute>
            <xsl:attribute name="version">2.0</xsl:attribute>
            <xsl:element name="OMA">
                <xsl:element name="OMS">
                    <xsl:attribute name="cd">linalg3</xsl:attribute>
                    <xsl:attribute name="name">vector</xsl:attribute>
                </xsl:element>
                <xsl:call-template name="om-kind-of-data">
                    <xsl:with-param name='arg' select="substring-before(text(),':')"/>
                </xsl:call-template>
                <xsl:call-template name="om-kind-of-data">
                    <xsl:with-param name='arg' select="substring-after(text(),':')"/>
                </xsl:call-template>
            </xsl:element>
        </xsl:element>
    </xsl:template>

</xsl:stylesheet>
