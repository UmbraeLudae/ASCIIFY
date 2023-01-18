Shader "Hidden/ASCIIFY"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CharTex ("CharTexture", 2D) = "white" {}        
        _DownscaleFactor ("DownscaleFactor", Integer) = 1
        _BackgroundColor("BackgroundColor", Color) = (0, 0, 0, 1)
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            Texture2D _MainTex;
            SamplerState sampler_MainTex_Point_Clamp;
            sampler2D _CharTex;
            float2 _MainTex_TexelSize;
            float4 _CharTex_TexelSize;
            float3 _BackgroundColor;

            int _DownscaleFactor;

            float2 padCharUV(float2 charUV)
            {
                return charUV;
                int2 charSize = floor(_CharTex_TexelSize.ww);
                int LookupCharCount = floor(_CharTex_TexelSize.z / float(_CharTex_TexelSize.w));
                return (charUV * ((charSize - float2(2, 2)) / charSize) * charSize + int2(1,1)) / charSize;
            }

            float3 maxMagnitude(float3 a, float3 b)
            {
                float t = a * a > b * b;
                return a * t + b * (1 - t);
            }

            float3 cellColor(float2 uv, int cellSize)
            {
                fixed3 cellColor = 0;
                float accumulatedBrightness = 0;
                float weightSum = 0;

                for(int x = 0; x < cellSize; x++)
                    for(int y = 0; y < cellSize; y++)
                    {
                        float2 sampleUV = uv + (x,y) * _MainTex_TexelSize;
                        fixed3 col = _MainTex.Sample(sampler_MainTex_Point_Clamp, sampleUV).rgb;
                        float brightness = length(col.rgb);                        
                        float weight = pow(brightness, 0);
                        accumulatedBrightness += brightness * weight;                        
                        weightSum += weight;
                    }
                
                float averageBrightness = accumulatedBrightness / weightSum;
                float minBrightnessDiff = 1;

                for(int x = 0; x < cellSize; x++)
                    for(int y = 0; y < cellSize; y++)
                    {
                        float2 sampleUV = uv + (x,y) * _MainTex_TexelSize;
                        fixed3 col = _MainTex.Sample(sampler_MainTex_Point_Clamp, sampleUV).rgb;
                        float brightness = length(col.rgb);
                        float brightnessDiff = abs(brightness - averageBrightness);
                        float t = brightnessDiff <= minBrightnessDiff + 0.001;
                        minBrightnessDiff = min(minBrightnessDiff, brightnessDiff);
                        cellColor = lerp(cellColor, col, t);
                    }
                
                return cellColor;
            }

            float sampleChar(float2 charUV, float brightness)
            {                
                charUV = padCharUV(charUV);
                int LookupCharCount = floor(_CharTex_TexelSize.z / float(_CharTex_TexelSize.w));
                charUV.x /= float(LookupCharCount);
                brightness = clamp(brightness, 0, 1);
                int brightnessTile = clamp(floor(brightness * LookupCharCount), 0, LookupCharCount - 1);
                charUV.x += brightnessTile / float(LookupCharCount);
                return tex2D(_CharTex, charUV);
            }

            fixed4 frag (v2f i) : SV_Target
            {   
                float2 aspect = float2(_ScreenParams.x / float(_ScreenParams.y), 1);
                int lines = floor(_ScreenParams.y / (1.0 / _CharTex_TexelSize.y));
                lines /= _DownscaleFactor;
                float2 charUV = (i.uv * aspect * lines);
                i.uv = floor(charUV) / aspect / float(lines);
                charUV %= 1.0;
                fixed3 col = cellColor(i.uv, (1.0 / _CharTex_TexelSize.y) * _DownscaleFactor);
                //col = _MainTex.Sample(sampler_MainTex_Point_Clamp, i.uv);
                float brightness = length(col);
                float mask = sampleChar(charUV, brightness);
                return float4(lerp(_BackgroundColor, col, mask).rgb, 1);
            }
            ENDCG
            
        }
    }
}
