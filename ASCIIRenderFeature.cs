using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ASCIIRenderFeature : ScriptableRendererFeature
{
    [SerializeField] private Texture2D charLookupTexture;
    [SerializeField] private int downscaleFactor = 2;
    [SerializeField] private Color background = Color.black;
    class ASCIIRenderPass : ScriptableRenderPass
    {
        private Material m_ASCIIFYMaterial;
        private Material ASCIIFYMaterial
        {
            get
            {
                if (m_ASCIIFYMaterial != null) return m_ASCIIFYMaterial;
                return m_ASCIIFYMaterial = new Material(Shader.Find("Hidden/ASCIIFY"));
            }
        }
        private Texture2D m_charLookupTexture;
        public Texture2D CharLookupTexture
        {
            get
            {
                if (m_charLookupTexture != null) return m_charLookupTexture;
                return m_charLookupTexture = Texture2D.whiteTexture;
            }
            set
            {
                m_charLookupTexture = value;
                ASCIIFYMaterial.SetTexture("_CharTex", value);
            }
        }
        private int m_DownscaleFactor;
        public int DownscaleFactor
        {
            get => m_DownscaleFactor;
            set
            {
                m_DownscaleFactor = value;
                ASCIIFYMaterial.SetInteger("_DownscaleFactor", value);
            }
        }

        private Color m_Background;
        public Color Background
        {
            get => m_Background;
            set
            {
                m_Background = value;
                ASCIIFYMaterial.SetColor("_BackgroundColor", value);
            }
        }
        private RenderTexture tempRT;

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            tempRT = RenderTexture.GetTemporary(renderingData.cameraData.cameraTargetDescriptor);
            var charSize = CharLookupTexture.height;
            var camera = renderingData.cameraData.camera;
            camera.rect = new Rect(0, 0, 1, 1);
            var res = camera.pixelRect.size;
            var targetRes = (Vector2)Vector2Int.FloorToInt(res / charSize / DownscaleFactor) * charSize * DownscaleFactor;
            var xViewportFactor = targetRes.x / (float)res.x;
            var yViewportFactor = targetRes.y / (float)res.y;
            var px = (1 - xViewportFactor) / 2;
            var py = (1 - yViewportFactor) / 2;
            camera.rect = new Rect(px, py, xViewportFactor, yViewportFactor);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
#if UNITY_EDITOR
            //exit if scene view
            if (renderingData.cameraData.camera == UnityEditor.SceneView.currentDrawingSceneView?.camera) return;
#endif
            var commandBuffer = new CommandBuffer() { name = "ASCIIFY" };
            var cameraColorTarget = renderingData.cameraData.renderer.cameraColorTarget;
            commandBuffer.Blit(cameraColorTarget, tempRT);
            commandBuffer.Blit(tempRT, cameraColorTarget, mat: ASCIIFYMaterial);
            context.ExecuteCommandBuffer(commandBuffer);
        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            RenderTexture.ReleaseTemporary(tempRT);
        }
    }

    ASCIIRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new ASCIIRenderPass();
        m_ScriptablePass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        m_ScriptablePass.CharLookupTexture = charLookupTexture;
        m_ScriptablePass.DownscaleFactor = downscaleFactor;
        m_ScriptablePass.Background = background;
    }

#if UNITY_EDITOR
    public void OnValidate()
    {
        if (m_ScriptablePass == null) return;
        m_ScriptablePass.CharLookupTexture = charLookupTexture;        
        m_ScriptablePass.DownscaleFactor = downscaleFactor = System.Math.Max(1, downscaleFactor);
        m_ScriptablePass.Background = background;
    }
#endif

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


